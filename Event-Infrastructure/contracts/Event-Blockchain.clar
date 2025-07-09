;; EventChain: Decentralized Event Ticketing Platform Smart Contract
;; A comprehensive blockchain-based event ticketing system enabling secure ticket creation,
;; sales, transfers, and validation with built-in secondary market functionality.
;; Features: Multi-tier event management, secure ticket authentication, resale marketplace,
;; bulk purchasing, gift transfers, and real-time event operations.

;; ERROR CONSTANTS

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-TICKET-NOT-FOUND (err u102))
(define-constant ERR-EVENT-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u104))
(define-constant ERR-SOLD-OUT (err u105))
(define-constant ERR-TICKET-ALREADY-USED (err u106))
(define-constant ERR-EVENT-ALREADY-EXISTS (err u107))
(define-constant ERR-INVALID-PRICE (err u108))
(define-constant ERR-INVALID-DATE (err u109))
(define-constant ERR-INVALID-QUANTITY (err u110))
(define-constant ERR-NOT-FOR-SALE (err u111))
(define-constant ERR-SELF-TRANSFER (err u112))
(define-constant ERR-ALREADY-CHECKED-IN (err u113))
(define-constant ERR-INVALID-INPUT (err u114))

;; APPLICATION CONSTANTS

(define-constant MAX-PRICE-LIMIT u1000000000)
(define-constant MAX-TICKETS-PER-USER u100)
(define-constant MAX-TITLE-LENGTH u100)
(define-constant MAX-DESCRIPTION-LENGTH u500)
(define-constant MAX-VENUE-LENGTH u100)
(define-constant VALIDATION-CODE-LENGTH u32)

;; DATA STRUCTURES

;; Primary event registry storing all event metadata
(define-map event-database
  { event-id: uint }
  {
    organizer-address: principal,
    event-name: (string-ascii 100),
    event-details: (string-utf8 500),
    venue-location: (string-ascii 100),
    event-date: uint,
    base-price: uint,
    total-capacity: uint,
    tickets-sold: uint,
    is-active: bool,
    allow-resale: bool,
    max-resale-price: uint
  }
)

;; Ticket ownership and status tracking
(define-map ticket-database
  { event-id: uint, ticket-id: uint }
  {
    owner-address: principal,
    sale-price: uint,
    is-for-sale: bool,
    is-used: bool,
    is-checked-in: bool
  }
)

;; Event counter per organizer for unique ID generation
(define-map organizer-counters
  { organizer: principal }
  { event-count: uint }
)

;; User ticket collections for efficient queries
(define-map user-ticket-collections
  { user-address: principal, event-id: uint }
  { ticket-list: (list 100 uint) }
)

;; Secure authentication codes for ticket validation
(define-map ticket-auth-codes
  { event-id: uint, ticket-id: uint }
  { auth-code: (buff 32) }
)

;; INPUT VALIDATION UTILITIES

(define-private (is-valid-string (input (string-ascii 100)))
  (and (> (len input) u0) (<= (len input) u100))
)

(define-private (is-valid-description (input (string-utf8 500)))
  (and (> (len input) u0) (<= (len input) u500))
)

(define-private (is-valid-venue (venue (string-ascii 100)))
  (and (> (len venue) u0) (<= (len venue) u100))
)

(define-private (is-valid-price (price uint))
  (and (> price u0) (<= price MAX-PRICE-LIMIT))
)

(define-private (is-valid-resale-price (price uint))
  (<= price MAX-PRICE-LIMIT)
)

;; EVENT MANAGEMENT UTILITIES

(define-read-only (get-organizer-event-count (organizer principal))
  (default-to u0 (get event-count (map-get? organizer-counters { organizer: organizer })))
)

(define-private (increment-event-counter (organizer principal))
  (let ((current-count (get-organizer-event-count organizer)))
    (map-set organizer-counters
      { organizer: organizer }
      { event-count: (+ current-count u1) }
    )
    (+ current-count u1)
  )
)

;; TICKET OWNERSHIP UTILITIES

(define-read-only (get-user-tickets (user-address principal) (event-id uint))
  (default-to (list) 
    (get ticket-list (map-get? user-ticket-collections { user-address: user-address, event-id: event-id }))
  )
)

(define-private (add-ticket-to-user (user-address principal) (event-id uint) (ticket-id uint))
  (let ((current-tickets (get-user-tickets user-address event-id)))
    (map-set user-ticket-collections
      { user-address: user-address, event-id: event-id }
      { ticket-list: (unwrap-panic (as-max-len? (append current-tickets ticket-id) u100)) }
    )
    true
  )
)

(define-private (remove-ticket-from-user (user-address principal) (event-id uint) (ticket-id uint))
  (let ((current-tickets (get-user-tickets user-address event-id)))
    (map-set user-ticket-collections
      { user-address: user-address, event-id: event-id }
      { ticket-list: (list) }
    )
    true
  )
)

;; SECURITY UTILITIES

(define-private (generate-auth-code (event-id uint) (ticket-id uint) (random-seed uint))
  (sha256 (concat (concat 
    (unwrap-panic (to-consensus-buff? event-id))
    (unwrap-panic (to-consensus-buff? ticket-id)))
    (unwrap-panic (to-consensus-buff? random-seed)))
  )
)

;; VALIDATION FUNCTIONS

(define-private (event-exists (event-id uint))
  (is-some (map-get? event-database { event-id: event-id }))
)

(define-private (ticket-exists (event-id uint) (ticket-id uint))
  (is-some (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id }))
)

(define-private (is-event-organizer (event-id uint) (user principal))
  (match (map-get? event-database { event-id: event-id })
    event-info (is-eq (get organizer-address event-info) user)
    false
  )
)

(define-private (is-ticket-owner (event-id uint) (ticket-id uint) (user principal))
  (match (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id })
    ticket-info (is-eq (get owner-address ticket-info) user)
    false
  )
)

(define-private (is-event-active (event-id uint))
  (match (map-get? event-database { event-id: event-id })
    event-info (get is-active event-info)
    false
  )
)

(define-private (is-event-current (event-id uint))
  (match (map-get? event-database { event-id: event-id })
    event-info (< block-height (get event-date event-info))
    false
  )
)

(define-private (is-ticket-unused (event-id uint) (ticket-id uint))
  (match (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id })
    ticket-info (not (get is-used ticket-info))
    false
  )
)

(define-private (is-not-checked-in (event-id uint) (ticket-id uint))
  (match (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id })
    ticket-info (not (get is-checked-in ticket-info))
    false
  )
)

;; EVENT CREATION & MANAGEMENT

(define-public (create-event 
  (event-name (string-ascii 100))
  (event-details (string-utf8 500))
  (venue-location (string-ascii 100))
  (event-date uint)
  (base-price uint)
  (total-capacity uint)
  (allow-resale bool)
  (max-resale-price uint)
)
  (let 
    (
      (event-organizer tx-sender)
      (validated-name (begin (asserts! (is-valid-string event-name) ERR-INVALID-INPUT) event-name))
      (validated-details (begin (asserts! (is-valid-description event-details) ERR-INVALID-INPUT) event-details))
      (validated-venue (begin (asserts! (is-valid-venue venue-location) ERR-INVALID-INPUT) venue-location))
      (validated-price (begin (asserts! (is-valid-price base-price) ERR-INVALID-PRICE) base-price))
      (validated-resale-price (begin (asserts! (is-valid-resale-price max-resale-price) ERR-INVALID-INPUT) max-resale-price))
      (new-event-id (increment-event-counter event-organizer))
    )
    
    ;; Validate event parameters
    (asserts! (> event-date block-height) ERR-INVALID-DATE)
    (asserts! (> total-capacity u0) ERR-INVALID-QUANTITY)
    
    ;; Create event record
    (map-set event-database
      { event-id: new-event-id }
      {
        organizer-address: event-organizer,
        event-name: validated-name,
        event-details: validated-details,
        venue-location: validated-venue,
        event-date: event-date,
        base-price: validated-price,
        total-capacity: total-capacity,
        tickets-sold: u0,
        is-active: true,
        allow-resale: allow-resale,
        max-resale-price: validated-resale-price
      }
    )
    
    (ok new-event-id)
  )
)

(define-public (update-event-info
  (event-id uint)
  (event-name (string-ascii 100))
  (event-details (string-utf8 500))
  (venue-location (string-ascii 100))
  (event-date uint)
  (is-active bool)
  (allow-resale bool)
  (max-resale-price uint)
)
  (let 
    (
      (event-organizer tx-sender)
      (validated-name (begin (asserts! (is-valid-string event-name) ERR-INVALID-INPUT) event-name))
      (validated-details (begin (asserts! (is-valid-description event-details) ERR-INVALID-INPUT) event-details))
      (validated-venue (begin (asserts! (is-valid-venue venue-location) ERR-INVALID-INPUT) venue-location))
      (validated-resale-price (begin (asserts! (is-valid-resale-price max-resale-price) ERR-INVALID-INPUT) max-resale-price))
    )
    
    ;; Validate permissions and constraints
    (asserts! (event-exists event-id) ERR-EVENT-NOT-FOUND)
    (asserts! (is-event-organizer event-id event-organizer) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> event-date block-height) ERR-INVALID-DATE)
    
    ;; Update event information
    (match (map-get? event-database { event-id: event-id })
      existing-event 
      (begin
        (map-set event-database
          { event-id: event-id }
          {
            organizer-address: event-organizer,
            event-name: validated-name,
            event-details: validated-details,
            venue-location: validated-venue,
            event-date: event-date,
            base-price: (get base-price existing-event),
            total-capacity: (get total-capacity existing-event),
            tickets-sold: (get tickets-sold existing-event),
            is-active: is-active,
            allow-resale: allow-resale,
            max-resale-price: validated-resale-price
          }
        )
        (ok true)
      )
      ERR-EVENT-NOT-FOUND
    )
  )
)

(define-public (cancel-event (event-id uint))
  (let
    (
      (event-organizer tx-sender)
      (event-info (unwrap! (map-get? event-database { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    
    ;; Validate cancellation permissions
    (asserts! (is-event-organizer event-id event-organizer) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-event-current event-id) ERR-EVENT-EXPIRED)
    
    ;; Deactivate event
    (map-set event-database
      { event-id: event-id }
      (merge event-info { is-active: false })
    )
    
    (ok true)
  )
)

;; TICKET PURCHASING SYSTEM

(define-public (buy-ticket (event-id uint))
  (let 
    (
      (buyer tx-sender)
      (event-info (unwrap! (map-get? event-database { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (ticket-price (get base-price event-info))
      (max-capacity (get total-capacity event-info))
      (current-sales (get tickets-sold event-info))
      (organizer (get organizer-address event-info))
      (new-ticket-id (+ current-sales u1))
    )
    
    ;; Validate purchase conditions
    (asserts! (is-event-active event-id) ERR-EVENT-NOT-FOUND)
    (asserts! (is-event-current event-id) ERR-EVENT-EXPIRED)
    (asserts! (<= new-ticket-id max-capacity) ERR-SOLD-OUT)
    
    ;; Process payment
    (try! (stx-transfer? ticket-price buyer organizer))
    
    ;; Update sales count
    (map-set event-database
      { event-id: event-id }
      (merge event-info { tickets-sold: new-ticket-id })
    )
    
    ;; Generate security authentication
    (let
      (
        (auth-code (generate-auth-code event-id new-ticket-id 
                   (default-to u0 (get-block-info? time u0))))
      )
      
      ;; Create ticket
      (map-set ticket-database
        { event-id: event-id, ticket-id: new-ticket-id }
        {
          owner-address: buyer,
          sale-price: u0,
          is-for-sale: false,
          is-used: false,
          is-checked-in: false
        }
      )
      
      ;; Store authentication
      (map-set ticket-auth-codes
        { event-id: event-id, ticket-id: new-ticket-id }
        { auth-code: auth-code }
      )
      
      ;; Register ownership
      (add-ticket-to-user buyer event-id new-ticket-id)
      
      (ok new-ticket-id)
    )
  )
)

(define-public (buy-ticket-pair (event-id uint))
  (let
    (
      (ticket-one (try! (buy-ticket event-id)))
      (ticket-two (try! (buy-ticket event-id)))
    )
    (ok (list ticket-one ticket-two))
  )
)

(define-public (buy-ticket-bundle (event-id uint))
  (let
    (
      (ticket-a (try! (buy-ticket event-id)))
      (ticket-b (try! (buy-ticket event-id)))
      (ticket-c (try! (buy-ticket event-id)))
      (ticket-d (try! (buy-ticket event-id)))
      (ticket-e (try! (buy-ticket event-id)))
    )
    (ok (list ticket-a ticket-b ticket-c ticket-d ticket-e))
  )
)

;; SECONDARY MARKET OPERATIONS

(define-public (list-for-resale (event-id uint) (ticket-id uint) (asking-price uint))
  (let
    (
      (seller tx-sender)
      (event-info (unwrap! (map-get? event-database { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (max-price (get max-resale-price event-info))
      (validated-price (begin (asserts! (is-valid-price asking-price) ERR-INVALID-PRICE) asking-price))
    )
    
    ;; Validate listing conditions
    (asserts! (ticket-exists event-id ticket-id) ERR-TICKET-NOT-FOUND)
    (asserts! (is-ticket-owner event-id ticket-id seller) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (get allow-resale event-info) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-event-current event-id) ERR-EVENT-EXPIRED)
    (asserts! (is-ticket-unused event-id ticket-id) ERR-TICKET-ALREADY-USED)
    (asserts! (is-not-checked-in event-id ticket-id) ERR-ALREADY-CHECKED-IN)
    (asserts! (<= validated-price max-price) ERR-INVALID-PRICE)
    
    ;; List ticket for sale
    (match (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id })
      ticket-info
      (begin
        (map-set ticket-database
          { event-id: event-id, ticket-id: ticket-id }
          (merge ticket-info { sale-price: validated-price, is-for-sale: true })
        )
        (ok true)
      )
      ERR-TICKET-NOT-FOUND
    )
  )
)

(define-public (remove-from-sale (event-id uint) (ticket-id uint))
  (let ((owner tx-sender))
    
    ;; Validate removal permissions
    (asserts! (ticket-exists event-id ticket-id) ERR-TICKET-NOT-FOUND)
    (asserts! (is-ticket-owner event-id ticket-id owner) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Remove listing
    (match (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id })
      ticket-info
      (begin
        (map-set ticket-database
          { event-id: event-id, ticket-id: ticket-id }
          (merge ticket-info { is-for-sale: false })
        )
        (ok true)
      )
      ERR-TICKET-NOT-FOUND
    )
  )
)

(define-public (buy-resale-ticket (event-id uint) (ticket-id uint))
  (let
    (
      (buyer tx-sender)
      (ticket-info (unwrap! (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
      (current-owner (get owner-address ticket-info))
      (sale-price (get sale-price ticket-info))
      (for-sale (get is-for-sale ticket-info))
      (event-info (unwrap! (map-get? event-database { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    
    ;; Validate purchase conditions
    (asserts! (is-event-active event-id) ERR-EVENT-NOT-FOUND)
    (asserts! (is-event-current event-id) ERR-EVENT-EXPIRED)
    (asserts! for-sale ERR-NOT-FOR-SALE)
    (asserts! (is-ticket-unused event-id ticket-id) ERR-TICKET-ALREADY-USED)
    (asserts! (is-not-checked-in event-id ticket-id) ERR-ALREADY-CHECKED-IN)
    (asserts! (not (is-eq buyer current-owner)) ERR-SELF-TRANSFER)
    
    ;; Process payment
    (try! (stx-transfer? sale-price buyer current-owner))
    
    ;; Transfer ownership
    (remove-ticket-from-user current-owner event-id ticket-id)
    (add-ticket-to-user buyer event-id ticket-id)
    
    ;; Update ticket record
    (map-set ticket-database
      { event-id: event-id, ticket-id: ticket-id }
      {
        owner-address: buyer,
        sale-price: u0,
        is-for-sale: false,
        is-used: false,
        is-checked-in: false
      }
    )
    
    (ok true)
  )
)

;; TICKET TRANSFER SYSTEM

(define-public (transfer-ticket (event-id uint) (ticket-id uint) (recipient principal))
  (let
    (
      (sender tx-sender)
      (ticket-info (unwrap! (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
    )
    
    ;; Validate transfer conditions
    (asserts! (is-ticket-owner event-id ticket-id sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-ticket-unused event-id ticket-id) ERR-TICKET-ALREADY-USED)
    (asserts! (is-not-checked-in event-id ticket-id) ERR-ALREADY-CHECKED-IN)
    (asserts! (not (is-eq sender recipient)) ERR-SELF-TRANSFER)
    
    ;; Execute transfer
    (remove-ticket-from-user sender event-id ticket-id)
    (add-ticket-to-user recipient event-id ticket-id)
    
    ;; Update ownership
    (map-set ticket-database
      { event-id: event-id, ticket-id: ticket-id }
      (merge ticket-info { owner-address: recipient, is-for-sale: false, sale-price: u0 })
    )
    
    (ok true)
  )
)

;; EVENT OPERATIONS

(define-public (validate-ticket (event-id uint) (ticket-id uint) (auth-code (buff 32)))
  (let
    (
      (organizer tx-sender)
      (event-info (unwrap! (map-get? event-database { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (ticket-info (unwrap! (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
      (stored-auth (unwrap! (map-get? ticket-auth-codes { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
    )
    
    ;; Validate redemption authority
    (asserts! (is-event-organizer event-id organizer) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-ticket-unused event-id ticket-id) ERR-TICKET-ALREADY-USED)
    
    ;; Verify authentication
    (asserts! (is-eq auth-code (get auth-code stored-auth)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Mark as used
    (map-set ticket-database
      { event-id: event-id, ticket-id: ticket-id }
      (merge ticket-info { is-used: true })
    )
    
    (ok true)
  )
)

(define-public (check-in-attendee (event-id uint) (ticket-id uint))
  (let
    (
      (organizer tx-sender)
      (event-info (unwrap! (map-get? event-database { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (ticket-info (unwrap! (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
    )
    
    ;; Validate check-in authority
    (asserts! (is-event-organizer event-id organizer) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-not-checked-in event-id ticket-id) ERR-ALREADY-CHECKED-IN)
    
    ;; Process check-in
    (map-set ticket-database
      { event-id: event-id, ticket-id: ticket-id }
      (merge ticket-info { is-checked-in: true })
    )
    
    (ok true)
  )
)

;; QUERY FUNCTIONS

(define-read-only (get-event-info (event-id uint))
  (match (map-get? event-database { event-id: event-id })
    event-info (ok event-info)
    ERR-EVENT-NOT-FOUND
  )
)

(define-read-only (get-ticket-info (event-id uint) (ticket-id uint))
  (match (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id })
    ticket-info (ok ticket-info)
    ERR-TICKET-NOT-FOUND
  )
)

(define-read-only (get-user-event-tickets (user-address principal) (event-id uint))
  (ok (get-user-tickets user-address event-id))
)

(define-read-only (check-ticket-validity (event-id uint) (ticket-id uint) (claimed-owner principal))
  (match (map-get? ticket-database { event-id: event-id, ticket-id: ticket-id })
    ticket-info (ok (and 
      (is-eq (get owner-address ticket-info) claimed-owner)
      (is-ticket-unused event-id ticket-id)
      (is-not-checked-in event-id ticket-id)
    ))
    ERR-TICKET-NOT-FOUND
  )
)

(define-read-only (get-organizer-total-events (organizer principal))
  (match (map-get? organizer-counters { organizer: organizer })
    counter-info (ok (get event-count counter-info))
    (ok u0)
  )
)

(define-read-only (verify-auth-code (event-id uint) (ticket-id uint) (submitted-code (buff 32)))
  (match (map-get? ticket-auth-codes { event-id: event-id, ticket-id: ticket-id })
    stored-auth (ok (is-eq (get auth-code stored-auth) submitted-code))
    (ok false)
  )
)

(define-read-only (get-available-tickets (event-id uint))
  (match (map-get? event-database { event-id: event-id })
    event-info (ok (- (get total-capacity event-info) (get tickets-sold event-info)))
    (ok u0)
  )
)

(define-read-only (get-user-portfolio (user-address principal))
  (ok (list))
)

;; CONTRACT INITIALIZATION

(begin
  true
)
# EventChain: Decentralized Event Ticketing Platform

A comprehensive blockchain-based event ticketing system built on the Stacks blockchain, enabling secure ticket creation, sales, transfers, and validation with built-in secondary market functionality.

## Features

- **Multi-tier Event Management**: Create and manage events with customizable parameters
- **Secure Ticket Authentication**: Cryptographic validation codes for ticket verification
- **Secondary Market**: Built-in resale marketplace with price controls
- **Bulk Purchasing**: Support for pair and bundle ticket purchases
- **Gift Transfers**: Easy ticket transfers between users
- **Real-time Operations**: Live event check-in and validation
- **Access Control**: Role-based permissions for organizers and attendees

## Quick Start

### Event Creation

```clarity
(contract-call? .eventchain create-event
  "Summer Music Festival"
  "An amazing outdoor music festival featuring top artists"
  "Central Park, NYC"
  u1000000  ;; Event date (block height)
  u500000   ;; Base price in microSTX
  u1000     ;; Total capacity
  true      ;; Allow resale
  u750000   ;; Max resale price
)
```

### Ticket Purchase

```clarity
;; Buy a single ticket
(contract-call? .eventchain buy-ticket u1)

;; Buy a pair of tickets
(contract-call? .eventchain buy-ticket-pair u1)

;; Buy a bundle of 5 tickets
(contract-call? .eventchain buy-ticket-bundle u1)
```

## Core Functions

### Event Management

#### `create-event`
Creates a new event with specified parameters.

**Parameters:**
- `event-name`: Event title (max 100 characters)
- `event-details`: Event description (max 500 characters)
- `venue-location`: Venue address (max 100 characters)
- `event-date`: Event date as block height
- `base-price`: Ticket price in microSTX
- `total-capacity`: Maximum number of tickets
- `allow-resale`: Whether resale is permitted
- `max-resale-price`: Maximum resale price

**Returns:** Event ID

#### `update-event-info`
Updates event information (organizer only).

#### `cancel-event`
Cancels an event and makes it inactive (organizer only).

### Ticket Operations

#### `buy-ticket`
Purchases a single ticket for an event.

**Parameters:**
- `event-id`: Target event identifier

**Returns:** Ticket ID

#### `buy-ticket-pair`
Purchases two tickets in a single transaction.

#### `buy-ticket-bundle`
Purchases five tickets in a single transaction.

#### `transfer-ticket`
Transfers ticket ownership to another user.

**Parameters:**
- `event-id`: Event identifier
- `ticket-id`: Ticket identifier
- `recipient`: New owner's principal

### Secondary Market

#### `list-for-resale`
Lists a ticket for resale on the secondary market.

**Parameters:**
- `event-id`: Event identifier
- `ticket-id`: Ticket identifier
- `asking-price`: Resale price in microSTX

#### `buy-resale-ticket`
Purchases a ticket from the secondary market.

#### `remove-from-sale`
Removes a ticket from the resale market.

### Event Operations

#### `validate-ticket`
Validates a ticket using its authentication code (organizer only).

**Parameters:**
- `event-id`: Event identifier
- `ticket-id`: Ticket identifier
- `auth-code`: 32-byte authentication code

#### `check-in-attendee`
Checks in an attendee at the event (organizer only).

## Query Functions

### Event Information

#### `get-event-info`
Retrieves complete event details.

```clarity
(contract-call? .eventchain get-event-info u1)
```

#### `get-available-tickets`
Returns the number of unsold tickets for an event.

### Ticket Information

#### `get-ticket-info`
Retrieves ticket details and status.

#### `get-user-event-tickets`
Returns all tickets owned by a user for a specific event.

#### `check-ticket-validity`
Verifies if a ticket is valid and unused.

### Authentication

#### `verify-auth-code`
Verifies an authentication code against stored values.

#### `get-organizer-total-events`
Returns the total number of events created by an organizer.

## Security Features

### Authentication Codes
Each ticket generates a unique 32-byte authentication code using:
- Event ID
- Ticket ID  
- Block timestamp
- SHA256 hashing

### Access Controls
- **Organizers**: Can create, update, cancel events, validate tickets, and check in attendees
- **Ticket Owners**: Can transfer tickets, list for resale, and remove from sale
- **Anyone**: Can purchase tickets and query public information

### Validation Checks
- Event existence and activity status
- Ticket ownership verification
- Price and capacity limits
- Date and time constraints
- Duplicate transaction prevention

## Data Structures

### Event Database
```clarity
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
```

### Ticket Database
```clarity
{
  owner-address: principal,
  sale-price: uint,
  is-for-sale: bool,
  is-used: bool,
  is-checked-in: bool
}
```

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR-UNAUTHORIZED-ACCESS | Insufficient permissions |
| u101 | ERR-EVENT-NOT-FOUND | Event doesn't exist |
| u102 | ERR-TICKET-NOT-FOUND | Ticket doesn't exist |
| u103 | ERR-EVENT-EXPIRED | Event has passed |
| u104 | ERR-INSUFFICIENT-PAYMENT | Payment amount too low |
| u105 | ERR-SOLD-OUT | No tickets available |
| u106 | ERR-TICKET-ALREADY-USED | Ticket already validated |
| u107 | ERR-EVENT-ALREADY-EXISTS | Event ID conflict |
| u108 | ERR-INVALID-PRICE | Price outside valid range |
| u109 | ERR-INVALID-DATE | Invalid event date |
| u110 | ERR-INVALID-QUANTITY | Invalid ticket quantity |
| u111 | ERR-NOT-FOR-SALE | Ticket not listed for sale |
| u112 | ERR-SELF-TRANSFER | Cannot transfer to self |
| u113 | ERR-ALREADY-CHECKED-IN | Attendee already checked in |
| u114 | ERR-INVALID-INPUT | Invalid input parameters |

## Use Cases

### Event Organizers
- Create and manage events
- Set ticket prices and capacity
- Control resale permissions
- Validate tickets at entry
- Check in attendees

### Ticket Buyers
- Purchase tickets directly
- Buy multiple tickets in bundles
- Transfer tickets to friends
- Resell tickets on secondary market

### Secondary Market
- List tickets for resale
- Set custom resale prices
- Automatic ownership transfer
- Price limit enforcement

## Constants

- `MAX-PRICE-LIMIT`: u1000000000 (maximum ticket price)
- `MAX-TICKETS-PER-USER`: u100 (maximum tickets per user)
- `MAX-TITLE-LENGTH`: u100 (maximum event title length)
- `MAX-DESCRIPTION-LENGTH`: u500 (maximum description length)
- `MAX-VENUE-LENGTH`: u100 (maximum venue name length)
- `VALIDATION-CODE-LENGTH`: u32 (authentication code length)

## Best Practices

1. **Event Planning**: Set event dates well in advance to allow ticket sales
2. **Pricing Strategy**: Consider setting reasonable resale price limits
3. **Capacity Management**: Monitor ticket sales and adjust marketing accordingly
4. **Security**: Always verify authentication codes before entry
5. **User Experience**: Provide clear event information and venue details
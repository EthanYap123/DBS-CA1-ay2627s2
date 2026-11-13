# HydroMax Shop (ST0525 DBS CA1)

Online shop for stainless steel bottles, built with Node.js, Express and PostgreSQL.
For CA1 I'm adding product reviews, comments with replies, and an admin sales dashboard.

## Prerequisites

- Node.js (v18 or later)
- PostgreSQL (with pgAdmin)

## Setup

1. Clone the repo and go into the app folder:
   ```
   git clone https://github.com/EthanYap123/DBS-CA1-ay2627s2.git
   cd DBS-CA1-ay2627s2/ecommerce
   ```
2. Create a database called `ecommerce` and restore it from the backup file provided on BrightSpace.
3. Update `ecommerce/.env` with your own PostgreSQL username and password (`DB_USER`, `DB_PASSWORD`).
4. Install dependencies:
   ```
   npm install
   ```

## Running the app

```
npm run dev
```

Then open http://localhost:3000/auth/login

## Test logins

| Role  | Username  | Password   |
|-------|-----------|------------|
| Admin | admin     | Password1! |
| User  | johnsmith | Password1! |

All the other seeded members use the same password.

## Project structure

The app follows routes -> controllers -> models, with the pages under `ecommerce/public`.

More details on the new database tables and functions will be added as the features are built.

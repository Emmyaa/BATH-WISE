# BathWise

Thai Baht exchange rates with official Bank of Thailand data (Flutter).

> Work in progress. The full README (screenshots, architecture, data flow,
> trade-offs) comes with the final phase.

## Getting started

1. Get a Bank of Thailand API token at https://portal.api.bot.or.th and
   subscribe it to the Exchange Rates, Loan Rates and Financial
   Institutions' Holidays APIs.
2. Create `.env` from the template and add your token (never commit it):

   ```sh
   cp .env.example .env
   ```

3. Install dependencies and generate code:

   ```sh
   flutter pub get
   dart run build_runner build -d
   ```

4. Run `flutter test`, then `flutter run`.

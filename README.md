# HelloID-Conn-Prov-Source-LACOE

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the necessary API key to connect to the LACOE service. Please contact the client's application manager to coordinate the connector requirements.
>
> ## Introduction

_HelloID-Conn-Prov-Source-LACOE_ is a _source_ connector. The purpose of this connector is to import _users_ or _humanresources_ and their _resourceRoster_. A resourceRoster represents a timetable consisting of days and parts which include work places.

### Endpoints
> [!IMPORTANT]
> There are two base URLs for the LACOE Data Exchange service. One for testing, and one for live data. Testing happens at https://lacoedataexchangeuat.lacoe.edu/ and live data comes from https://lacoedataexchange.lacoe.edu/
Currently the following endpoints are being used.

| Endpoint               | Method | Description                                                       |
| ---------------------- | ------ | ----------------------------------------------------------------- |
| api/v1/token              | POST   |                                                                   |
| api/v2/EmployeeDemographics              | GET    | Default endpoint to get all users                                 |
| api/v1/EmployeeActivePositions     | GET    | Returns all active positions for employees             |
| api/v1/EmployeePrimeJobAttributes     | GET    | Returns extended information about each employees' singular prime job                                     |

- The API documentation can be found at the URL below.
  - [LACOE Data Exchange API documentation](https://lacoedataexchange.lacoe.edu/docs/).

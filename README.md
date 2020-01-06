# crm_donor_duplicates

## Application to track donor relationships with ministry staff members.

### Problem:
Ministry staff are responsible for building and developing their own donor support teams. There is a high chance of several ministry staff people knowing the same potential donors so a system needs to be in place to limit the number of staff people who attempt to contact a particular potential donor.

Customer is currently a Google spreadsheet with over 4 thousand rows. Each staff person has several rows to record their donor relationships. One particular donor may have multiple lines to capture various name spellings (nicknames, maiden name, etc.). Each donor may be mentioned multiple times if they are connected to more than one staff person.

When a staff person enters a new potential donor, the spreadsheet will see if any other donor has an exact match of the first and last names and will indicate the number or times this donor is listed on the sheet. Then the user is responsible for locating the other record(s) and coordinating with any other staff person already connected to this donor.

The spreadsheet solution is far from ideal, with significant room for error:
- Staff users are required to do a lot of manual work, which makes it less likely that they will diligently follow the full process. This is proven by how staff currently utilize the system.
- Typos or incorrect spellings of names will not find a match.
- Significant duplication of data.
- Maintenance/cleanup would be meticulous and time consuming. Due to this, maintenance is simply never performed because no one has the time.

### Solution:
The main focus was to take as much responsibility off of the user as possible. Making the user's job easier means they are more likely to follow the process and essentially improves the overall success of the appliation.

Secondly, there is a significant advantage to utilizing user input to constantly maintain and clean up the data. Using an approximate match search, we can find potential matches and ask the user to select any donor records that are the same person, then merge those records into one.

#### Adding a New Donor: Process Flow
When a user adds a new donor, they input the donor's first name, last name, and any altername first names the donor may have.

The application will check the database for an exising donor that matches the last name and first/alternate names.
  1. If a match is found, the application adds a new relationship record connecting user and existing donor, and if any additional alternate names were provided they will be added to the donor record.
  2. Otherwise, the application adds a new donor record, including the list of alternate names, and adds a new relationship record connecting user and new donor.

For every donor on list, any other staff connected to the same donor will be listed by name for a clear idea of who to reach out to before contacting a potential donor.

### Functionality
#### Normal User:
- log in to their profile
- view their profile information and edit their name or email address
- view their donor list
  - add a new donor (potential or current)
  - edit a donor's names or the type of relationship this user has with them
  - remove a donor from the user's list (deletes the donor relationship record but the donor record remains in the database)
- view list of all donors

#### Admin User:
Has same functionality as a normal user plus:
- view list of all donors
  - edit donor names
  - delete a donor record from database (along with any relevant user relationships)
- view list of all users (staff members)
  - edit user name, email, active status, admin status
  - delete a user from the database
  - reset user password

### Changes To Come
- Instead of having an alternate names column for donor records, create another table of aliases.
- Implement Levenshtein distance equation for potential matches.
  - Display potential matches to user with checkboxes so they can indicate whether any of the donors are the same person.
- Handle non-names when users input "Mr.", "Mrs.", "Parents", etc. instead of of a first name.
- Handle input if user tries to include an alternate name in first name field within parentheses: "William (Bill)"
- Add another column for a unique identifier in case two donors have the same first and last name (eg. birthday, address, etc.).
- Implement a "Donors from departing staff" page where the donors that were connected to a person transitioning off the staff team would be listed so other current staff could reach out to potentially invite any of these donors to join their donor team.
- Simplify donor and user abstractions to only include the necessary state for a donor or user record from the data base. Don't use donor class to send data to the database.
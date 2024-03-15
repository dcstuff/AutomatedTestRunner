# Automated Test Runner

Firstly, many thanks to this fine repo from which I took a great many inspiration: https://github.com/sfdcjedi/sfdc-automated-tests/. How many an inspiration? A *great* many.

## In a nutshell (ALL. THE. NUTS.)
Use the Automated Test Runner to schedule groups of tests to run at different times and have the results emailed to different people.

**Example 1:** Have every non-namespaced test in the org, except for the tests in the `ThisClassReallyBlows` and `NotCodeCoverageIPromise` classes, run every Thursday at 2 pm and email the results to all System Administrators, folks with the Snorgle permission set, and Bob, because he likes that sorta thing.

**Example 2:** Have all tests with *bacon* anywhere in the class name, including managed packaged tests -- you know those bacon-related packages -- run daily at 5 am and email the results to Han Solo and Luke Skywalker. Don't get me wrong, neither of them like Apex, but they do need the test results.

## Config

Create Automated Test Setup (`AutomatedTestSetup__mdt`) custom metadata records as needed.

![sample configuration](/readme-extras/automated-test-runner.png)

### Fields

#### Is Active

If checked, this test configuration will be scheduled when the Automated Test Runner is launched. Unchecking already active scheduled test runs will not unschedule them. The associated scheduled job must be deleted.

#### Test Name Pattern

Filter the test classes to run to only include those that match this SOQL pattern, ex: %bacon%. Do not include any quotes.

#### Include Namespaced Classes

If checked, namespaced, i.e. packaged, classes, will be in included in the test run.

#### Excluded Classes

These Apex test classes will NOT be run, regardless of a defined Test Name Pattern.

#### Cron

This is the schedule the tests will run on.

#### Minutes To Wait

The Automated Test Runner will check in intervals of [this] many minutes to see if the test run is complete.

#### Show Stack Trace

If checked, the stack traces for failed tests will be included in the emailed report.

#### Profile To Email

Users of this profile will be emailed the test results. These will be combined with users in any configured permission set or list of user IDs.

#### Permission Set To Email

Users of this permission set will be emailed the test results. These will be combined with users in any configured profile or list of user IDs.

#### User Ids

Users defined here will be emailed the test results. These will be combined with users in any configured profile or permission set.

#### Excluded User Ids

Users defined here will NOT be emailed, regardless of whether they meet other configured criteria.

## Usage

To run all active `AutomatedTestSetup__mdt` records at their configured schedules.
```
AutomatedTestRunner.run();
```

Specify an `AutomatedTestSetup__mdt` record and a cron expression to run that record at an overridden schedule. The record doesn’t have to be active.
```
AutomatedTestRunner.run('stuff', '0 35 15 23 2 ? 2024');
```

Specify only an `AutomatedTestSetup__mdt` record to run that record at its configured schedule. The record doesn’t have to be active.
```
AutomatedTestRunner.run('stuff', null);
```

To run all active `AutomatedTestSetup__mdt` records at an overridden schedule.
```
AutomatedTestRunner.run(null, '0 35 15 23 2 ? 2024');
```

## Final thoughts

Be true to yourself. Or whatever. :roll_eyes:<br>
Made myself laugh.
@IsTest
class AutomatedTestReport_Test {
  static final String PROFILE = [SELECT Name FROM Profile LIMIT 1].Name;
  static final String PERMISSION_SET = [SELECT Name FROM PermissionSet LIMIT 1].Name;

  static final String CUSTOM_METADATA_JSON =
    '{"Label": "blah", "ProfileToEmail__c": "' +
    PROFILE +
    '", "PermissionSetToEmail__c": "' +
    PERMISSION_SET +
    '", "UserIds__c": "' +
    UserInfo.getUserId() +
    '", "ExcludedUserIds__c": "005000000000AAA"}';

  static final String TEST_RUN_RESULT_JSON = '{ "Status": "Completed" }';

  static final String TEST_RESULTS_JSON =
    '[ {' +
    '  "MethodName" : "test1",' +
    '  "Outcome" : "Pass",' +
    '  "ApexClass" : {' +
    '    "Name" : "SomeTestClass"' +
    '  }' +
    '}, {' +
    '  "MethodName" : "test2",' +
    '  "Outcome" : "Fail",' +
    '  "ApexClass" : {' +
    '    "Name" : "SomeTestClass"' +
    '  }' +
    '} ]';

  @IsTest
  static void testConstructor() {
    AutomatedTestSetup__mdt testSetup = (AutomatedTestSetup__mdt) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      AutomatedTestSetup__mdt.class
    );

    Test.startTest();
    AutomatedTestReport testReport = new AutomatedTestReport(testSetup, null);
    Test.stopTest();

    Assert.areEqual(testSetup, testReport.testSetup);
  }

  @IsTest
  static void testExecute() {
    AutomatedTestSetup__mdt testSetup = (AutomatedTestSetup__mdt) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      AutomatedTestSetup__mdt.class
    );
    AutomatedTestReport.testRunResult = (ApexTestRunResult) JSON.deserialize(
      TEST_RUN_RESULT_JSON,
      ApexTestRunResult.class
    );
    AutomatedTestReport.testResults = (List<ApexTestResult>) JSON.deserialize(
      TEST_RESULTS_JSON,
      List<ApexTestResult>.class
    );

    Test.startTest();
    System.schedule(
      'AutomatedTestReport',
      '0 0 0 * * ?',
      new AutomatedTestReport(testSetup, null)
    );
    Test.stopTest();

    Integer numberOfScheduledJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status = 'Queued' AND ApexClass.Name = 'AutomatedTestReport'
    ];

    Assert.areEqual(1, numberOfScheduledJobs);
  }
}
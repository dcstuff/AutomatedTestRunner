@IsTest
class AutomatedTestRunner_Test {
  static final String CUSTOM_METADATA_JSON =
    '[{"Label": "blah", "Cron__c": "0 0 2 * * ?", "MinutesToWait__c": "30", "TestNamePattern__c": "%blah%", "ExcludedClasses__c": "skipme", "UserIds__c": "' +
    UserInfo.getUserId() +
    '"},{"Label": "blah2", "Cron__c": "0 0 2 * * ?", "MinutesToWait__c": "30", "TestNamePattern__c": "%blah%", "UserIds__c": "' +
    UserInfo.getUserId() +
    '"}]';

  static final String APEX_CLASS_JSON = '[ { "NamespacePrefix": null, "Name": "blah"} ]';

  @IsTest
  static void testConstructor() {
    List<AutomatedTestSetup__mdt> testSetups = (List<AutomatedTestSetup__mdt>) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      List<AutomatedTestSetup__mdt>.class
    );

    AutomatedTestRunner.testSetups = testSetups;

    Test.startTest();
    AutomatedTestRunner testRunner = new AutomatedTestRunner(testSetups[0]);
    Test.stopTest();

    Assert.areEqual(testSetups[0], testRunner.testSetup);
  }

  @IsTest
  static void testSetup() {
    List<AutomatedTestSetup__mdt> testSetups = (List<AutomatedTestSetup__mdt>) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      List<AutomatedTestSetup__mdt>.class
    );

    AutomatedTestRunner.testSetups = testSetups;
    AutomatedTestRunner.apexClasses = new List<ApexClass>();

    Test.startTest();
    AutomatedTestRunner.run();
    Test.stopTest();

    Integer numberOfScheduledJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status = 'Queued' AND ApexClass.Name = 'AutomatedTestRunner'
    ];

    Assert.areEqual(testSetups.size(), numberOfScheduledJobs);

    numberOfScheduledJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status = 'Queued' AND ApexClass.Name = 'AutomatedTestReport'
    ];

    Assert.areEqual(0, numberOfScheduledJobs);
  }

  @IsTest
  static void testSetupWithDefinedConfigAndCron() {
    List<AutomatedTestSetup__mdt> testSetups = (List<AutomatedTestSetup__mdt>) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      List<AutomatedTestSetup__mdt>.class
    );

    AutomatedTestRunner.testSetups = new List<AutomatedTestSetup__mdt>{
      testSetups[0]
    };

    Test.startTest();
    AutomatedTestRunner.run(testSetups[1].Label, '0 0 3 * * ?');
    Test.stopTest();

    Integer numberOfScheduledJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status = 'Queued' AND ApexClass.Name = 'AutomatedTestRunner'
    ];

    Assert.areEqual(1, numberOfScheduledJobs);
  }

  @IsTest
  static void testAlreadyScheduled() {
    List<AutomatedTestSetup__mdt> testSetups = (List<AutomatedTestSetup__mdt>) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      List<AutomatedTestSetup__mdt>.class
    );

    AutomatedTestRunner.testSetups = testSetups;
    AutomatedTestRunner.apexClasses = new List<ApexClass>();
    AutomatedTestRunner.run();

    Test.startTest();
    AutomatedTestRunner.run();
    Test.stopTest();

    Integer numberOfScheduledJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status = 'Queued' AND ApexClass.Name = 'AutomatedTestRunner'
    ];

    Assert.areEqual(testSetups.size(), numberOfScheduledJobs);
  }

  @IsTest
  static void testApexClassRetrievalAndTestKickoff() {
    List<AutomatedTestSetup__mdt> testSetups = (List<AutomatedTestSetup__mdt>) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      List<AutomatedTestSetup__mdt>.class
    );
    List<ApexClass> apexClasses = (List<ApexClass>) JSON.deserialize(
      APEX_CLASS_JSON,
      List<ApexClass>.class
    );

    AutomatedTestRunner.testSetups = testSetups;
    AutomatedTestRunner.apexClasses = apexClasses;

    Test.startTest();
    AutomatedTestRunner.run();
    Test.stopTest();

    Integer numberOfScheduledJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status = 'Queued' AND ApexClass.Name = 'AutomatedTestReport'
    ];

    Assert.areEqual(apexClasses.size(), numberOfScheduledJobs);
  }

  @IsTest
  static void customMetadataQueryAndSoslCoverage() {
    AutomatedTestSetup__mdt testSetup = ((List<AutomatedTestSetup__mdt>) JSON.deserialize(
      CUSTOM_METADATA_JSON,
      List<AutomatedTestSetup__mdt>.class
    ))[0];

    AutomatedTestRunner.getAutomatedTestSetups(null);
    AutomatedTestRunner.getApexTestClasses(testSetup);
  }
}
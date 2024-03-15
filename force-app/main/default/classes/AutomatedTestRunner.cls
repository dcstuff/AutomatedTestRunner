public with sharing class AutomatedTestRunner implements Schedulable {
  static final String THIS_CLASS = 'AutomatedTestRunner';
  static final List<String> STATUSES_TO_SKIP = new List<String>{
    'Holding',
    'Preparing',
    'Processing',
    'Queued'
  };

  @TestVisible
  static List<AutomatedTestSetup__mdt> testSetups;

  @TestVisible
  static List<ApexClass> apexClasses;

  @TestVisible
  final AutomatedTestSetup__mdt testSetup;

  public AutomatedTestRunner(AutomatedTestSetup__mdt testSetup) {
    this.testSetup = testSetup;
  }

  public static void run() {
    reallyRun(null, null);
  }

  public static void run(String testSetupApiName, String cron) {
    if (String.isBlank(testSetupApiName) && String.isBlank(cron)) {
      return;
    }

    reallyRun(testSetupApiName, cron);
  }

  static void reallyRun(String testSetupApiName, String cron) {
    Set<String> alreadyScheduledJobs = new Map<String, SObject>(
        [
          SELECT CronTrigger.CronJobDetail.Name Id
          FROM AsyncApexJob
          WHERE
            ApexClass.Name = :THIS_CLASS
            AND Status IN :STATUSES_TO_SKIP
            AND CronTrigger.CronJobDetail.Name != NULL
          GROUP BY CronTrigger.CronJobDetail.Name
        ]
      ).keySet();

    try {
      for (
        AutomatedTestSetup__mdt testSetup : getAutomatedTestSetups(testSetupApiName)) {
        String cronExp = cron ?? testSetup.Cron__c;
        String jobName = THIS_CLASS + ' ' + testSetup.Label + ' / ' + cronExp;

        if (!alreadyScheduledJobs.contains(jobName)) {
          try {
            System.schedule(jobName, cronExp, new AutomatedTestRunner(testSetup));
          } catch (StringException e) {
            System.debug(LoggingLevel.ERROR, e.getMessage());
          }
        }
      }
    } catch (AsyncException e) {
      System.debug(LoggingLevel.ERROR, e.getMessage());
    }
  }

  @TestVisible
  static List<AutomatedTestSetup__mdt> getAutomatedTestSetups(String testSetupApiName) {
    return testSetups ?? Database.query(
        'SELECT ' +
          'Label, ' +
          'Cron__c, ' +
          'ExcludedClasses__c, ' +
          'ExcludedUserIds__c, ' +
          'IncludeNamespacedClasses__c, ' +
          'MinutesToWait__c, ' +
          'PermissionSetToEmail__c, ' +
          'ProfileToEmail__c, ' +
          'ShowStackTrace__c, ' +
          'UserIds__c, ' +
          'TestNamePattern__c ' +
          'FROM AutomatedTestSetup__mdt ' +
          'WHERE ' +
          (testSetupApiName == null
            ? 'IsActive__c = TRUE'
            : 'DeveloperName = \'' + String.escapeSingleQuotes(testSetupApiName) + '\'')
      );
  }

  public void execute(SchedulableContext sc) {
    apexClasses = getApexTestClasses(testSetup);
    if (apexClasses.isEmpty()) {
      return;
    }

    List<ApexTestQueueItem> testQueueItems = createQueueItems(apexClasses);
    Id jobId;

    if (!Test.isRunningTest()) {
      try {
        insert testQueueItems;
      } catch (DmlException e) {
        // womp womp
        System.debug(LoggingLevel.ERROR, e.getMessage());
        return;
      }

      jobId = [
        SELECT ParentJobId
        FROM ApexTestQueueItem
        WHERE Id = :testQueueItems[0].Id
      ].ParentJobId;
    }

    String nextExecutionCron = getNextExecutionCron(testSetup);

    try {
      System.schedule(
        'AutomatedTestReport ' + jobId + ' / ' + nextExecutionCron,
        nextExecutionCron,
        new AutomatedTestReport(testSetup, jobId)
      );
    } catch (AsyncException e) {
      System.debug(LoggingLevel.ERROR, e.getMessage());
    }
  }

  @TestVisible
  static List<ApexClass> getApexTestClasses(AutomatedTestSetup__mdt testSetup) {
    if (apexClasses != null) {
      return apexClasses;
    }

    String queryString = 'FIND \'@istest or testmethod\' IN ALL FIELDS RETURNING ApexClass(Name ';

    Boolean hasWhere = false;
    List<String> excludedClasses;

    if (String.isNotBlank(testSetup.TestNamePattern__c)) {
      queryString +=
        'WHERE Name LIKE \'' +
        String.escapeSingleQuotes(testSetup.TestNamePattern__c) + '\' ';
      hasWhere = true;
    }

    if (!testSetup.IncludeNamespacedClasses__c) {
      queryString += (hasWhere ? 'AND ' : 'WHERE ') + 'NamespacePrefix = NULL ';
      hasWhere = true;
    }

    if (String.isNotBlank(testSetup.ExcludedClasses__c)) {
      excludedClasses = testSetup.ExcludedClasses__c.trim().split('\\s*,\\s*');
      queryString += (hasWhere ? 'AND ' : 'WHERE ') + 'Name NOT IN :excludedClasses ';
    }

    queryString += 'ORDER BY Name)';

    return (List<ApexClass>) Search.query(queryString)[0];
  }

  List<ApexTestQueueItem> createQueueItems(List<ApexClass> apexClasses) {
    List<ApexTestQueueItem> testQueueItems = new List<ApexTestQueueItem>();
    for (ApexClass testClass : apexClasses) {
      testQueueItems.add(new ApexTestQueueItem(ApexClassId = testClass.Id));
    }
    return testQueueItems;
  }

  public static String getNextExecutionCron(AutomatedTestSetup__mdt testSetup) {
    Datetime now = System.now().addMinutes((Integer) testSetup.MinutesToWait__c);

    return '0 ' + // second
      now.format('m') + // minute
      ' ' +
      now.format('H') + // hour
      ' ' +
      now.format('d') + // day
      ' ' +
      now.format('M') + // month
      ' ? ' + // day of week
      now.format('yyyy'); // year
  }
}
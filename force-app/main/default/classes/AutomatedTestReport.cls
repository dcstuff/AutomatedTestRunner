public with sharing class AutomatedTestReport implements Schedulable {
  final Id jobId;
  @TestVisible
  final AutomatedTestSetup__mdt testSetup;
  @TestVisible
  static ApexTestRunResult testRunResult;
  @TestVisible
  static List<ApexTestResult> testResults;
  Boolean isAllMethodsPassed = false;

  public AutomatedTestReport(AutomatedTestSetup__mdt testSetup, String jobId) {
    this.jobId = jobId;
    this.testSetup = testSetup;
  }

  public void execute(SchedulableContext sc) {
    testRunResult = getTestRunResult(jobId);

    switch on testRunResult.Status {
      when 'Queued', 'Processing' {
        String nextExecutionCron = AutomatedTestRunner.getNextExecutionCron(testSetup);

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
      when 'Completed', 'Failed' {
        testResults = getTestResults(jobId);
        emailResults();
      }
    }
  }

  static ApexTestRunResult getTestRunResult(Id jobId) {
    return testRunResult ?? [SELECT Status FROM ApexTestRunResult WHERE AsyncApexJobId = :jobId];
  }

  static List<ApexTestResult> getTestResults(Id jobId) {
    return testResults ?? [
      SELECT ApexClass.Name, MethodName, Outcome, Message, StackTrace
      FROM ApexTestResult
      WHERE AsyncApexJobId = :jobId
      ORDER BY ApexClass.Name, MethodName
    ];
  }

  void emailResults() {
    Set<Id> recipientIds = getRecipientIds();

    if (recipientIds.isEmpty()) {
      return;
    }

    String emailBody = generateReport();
    sendEmail(recipientIds, emailBody);
  }

  Set<Id> getRecipientIds() {
    Set<Id> recipientIds = new Set<Id>();

    if (String.isNotBlank(testSetup.ProfileToEmail__c)) {
      recipientIds.addAll(
        new Map<Id, User>(
            [
              SELECT Id
              FROM User
              WHERE Profile.Name = :testSetup.ProfileToEmail__c.trim()
            ]
          ).keySet()
      );
    }

    if (String.isNotBlank(testSetup.PermissionSetToEmail__c)) {
      recipientIds.addAll(
        new Map<Id, AggregateResult>(
            [
              SELECT AssigneeId Id
              FROM PermissionSetAssignment
              WHERE
                PermissionSet.Name = :testSetup.PermissionSetToEmail__c.trim()
              GROUP BY AssigneeId
            ]
          ).keySet()
      );
    }

    if (String.isNotBlank(testSetup.UserIds__c)) {
      recipientIds.addAll(new Set<Id>((List<Id>) (testSetup.UserIds__c.trim().split('\\s*,\\s*'))));
    }

    if (String.isNotBlank(testSetup.ExcludedUserIds__c)) {
      recipientIds.removeAll(new Set<Id>((List<Id>) (testSetup.ExcludedUserIds__c.trim().split('\\s*,\\s*'))));
    }

    return recipientIds;
  }

  String generateReport() {
    Integer methodsPassed = 0;
    Integer totalMethods = 0;
    String currentClass = '';
    Boolean showStackTrace = testSetup.ShowStackTrace__c;

    String failTable = '<table border="1" cellpadding="5px">';
    for (ApexTestResult result : testResults) {
      if (result.Outcome == 'Pass') {
        methodsPassed++;
      } else {
        if (result.ApexClass.Name != currentClass) {
          currentClass = result.ApexClass.Name;
          failTable +=
            '<tr style="background: #ddd; font-weight: bold;"><td colspan="' +
            (showStackTrace ? 3 : 2) +
            '">' +
            currentClass +
            '</td></tr>\n';
        }

        failTable +=
          '<tr><td>' +
          result.MethodName +
          '</td><td>' +
          result.Message +
          '</td>' +
          (showStackTrace ? '<td>' + (result.StackTrace ?? '') + '</td>' : '') +
          '</tr>\n';
      }
      totalMethods++;
    }
    failTable += '</table>';

    String fullBody =
      '<p>Test methods passed (' +
      methodsPassed +
      '/' +
      totalMethods +
      ')</p>\n';

    if (totalMethods != methodsPassed) {
      fullBody += '<p>Failures summary:</p>\n' + failTable;
    } else {
      fullBody += '<p>All tests passed.</p>\n';
      isAllMethodsPassed = true;
    }

    return fullBody;
  }

  void sendEmail(Set<Id> userIds, String htmlBody) {
    String orgName = DomainParser.parse(URL.getOrgDomainUrl()).getSandboxName();
    orgName = orgName == null ? '*** PRODUCTION ***' : 'org "' + orgName + '"';

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    for (Id userId : userIds) {
      Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
      mail.setTargetObjectId(userId);
      mail.setSubject(
        'Automated test results for ' +
          orgName +
          '", config "' +
          testSetup.Label +
          '": ' +
          (isAllMethodsPassed ? 'Pass' : 'Fail')
      );
      mail.setHtmlBody(htmlBody);
      emails.add(mail);
    }

    try {
      Messaging.sendEmail(emails, false);
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, e.getMessage());
    }
  }
}
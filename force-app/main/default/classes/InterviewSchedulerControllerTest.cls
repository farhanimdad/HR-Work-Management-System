@isTest
private class InterviewSchedulerControllerTest {

    @testSetup
    static void setupData() {
        Candidate__c cand = new Candidate__c(
            Name = 'Jane Candidate',
            Email__c = 'jane.candidate@example.com'
        );
        insert cand;

        Employee__c emp = new Employee__c(
            Name = 'John Interviewer',
            Email__c = 'john.interviewer@example.com'
        );
        insert emp;
    }

    @isTest
    static void testGetOptions() {
        Test.startTest();
        List<InterviewSchedulerController.OptionWrapper> cands = InterviewSchedulerController.getCandidates();
        List<InterviewSchedulerController.OptionWrapper> intvs = InterviewSchedulerController.getInterviewers();
        Test.stopTest();

        System.assertNotEquals(0, cands.size(), 'Candidate options should not be empty');
        System.assertNotEquals(0, intvs.size(), 'Interviewer options should not be empty');
    }

    @isTest
    static void testSuccessSchedule() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Date futureDate = Date.today().addDays(3);
        Time startTime = Time.newInstance(10, 0, 0, 0);
        Time endTime = Time.newInstance(11, 0, 0, 0);

        Interview__c interview = new Interview__c(
            Candidate__c = cand.Id,
            Interviewer__c = emp.Id,
            Interview_Date__c = futureDate,
            Start_Time__c = startTime,
            End_Time__c = endTime,
            Round__c = 'Technical Round',
            Mode__c = 'Online'
        );

        Test.startTest();
        Id interviewId = InterviewSchedulerController.scheduleInterview(interview);
        Test.stopTest();

        System.assertNotEquals(null, interviewId, 'Returned interview ID should not be null');
        Interview__c inserted = [SELECT Id, Status__c FROM Interview__c WHERE Id = :interviewId];
        System.assertEquals('Scheduled', inserted.Status__c, 'Status should default to Scheduled');
    }

    @isTest
    static void testPastDateError() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Date pastDate = Date.today().addDays(-2);

        Interview__c interview = new Interview__c(
            Candidate__c = cand.Id,
            Interviewer__c = emp.Id,
            Interview_Date__c = pastDate,
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            End_Time__c = Time.newInstance(11, 0, 0, 0),
            Round__c = 'HR Round'
        );

        Test.startTest();
        try {
            InterviewSchedulerController.scheduleInterview(interview);
            System.assert(false, 'Should have thrown exception for past date');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('past') || e.getMessage().contains('Interview'), 'Expected past date validation message');
        }
        Test.stopTest();
    }

    @isTest
    static void testOverlappingSlotError() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Date futureDate = Date.today().addDays(5);

        // Schedule first interview (10:00 - 11:00)
        Interview__c firstInt = new Interview__c(
            Candidate__c = cand.Id,
            Interviewer__c = emp.Id,
            Interview_Date__c = futureDate,
            Start_Time__c = Time.newInstance(10, 0, 0, 0),
            End_Time__c = Time.newInstance(11, 0, 0, 0),
            Round__c = 'HR Round',
            Status__c = 'Scheduled'
        );
        insert firstInt;

        // Attempt second interview for same interviewer during overlapping slot (10:30 - 11:30)
        Interview__c secondInt = new Interview__c(
            Candidate__c = cand.Id,
            Interviewer__c = emp.Id,
            Interview_Date__c = futureDate,
            Start_Time__c = Time.newInstance(10, 30, 0, 0),
            End_Time__c = Time.newInstance(11, 30, 0, 0),
            Round__c = 'Technical Round'
        );

        Test.startTest();
        try {
            InterviewSchedulerController.scheduleInterview(secondInt);
            System.assert(false, 'Should have thrown exception for overlapping slot');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('booked') || e.getMessage().contains('time slot'), 'Expected overlap message');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvalidTimeAndNulls() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        Employee__c emp = [SELECT Id FROM Employee__c LIMIT 1];

        Date futureDate = Date.today().addDays(5);

        // End time before start time
        Interview__c invalidTimes = new Interview__c(
            Candidate__c = cand.Id,
            Interviewer__c = emp.Id,
            Interview_Date__c = futureDate,
            Start_Time__c = Time.newInstance(11, 0, 0, 0),
            End_Time__c = Time.newInstance(10, 0, 0, 0),
            Round__c = 'Technical Round'
        );

        Test.startTest();
        try {
            InterviewSchedulerController.scheduleInterview(invalidTimes);
            System.assert(false, 'Should throw exception when end time <= start time');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('after'), 'Expected end time error');
        }

        try {
            InterviewSchedulerController.scheduleInterview(null);
            System.assert(false, 'Should throw exception for null interview');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('null'), 'Expected null record error');
        }
        Test.stopTest();
    }
}

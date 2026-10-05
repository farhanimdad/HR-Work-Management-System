public with sharing class InterviewSchedulerController {

    public class OptionWrapper {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public OptionWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getCandidates() {
        List<OptionWrapper> options = new List<OptionWrapper>();
        for (Candidate__c c : [
            SELECT Id, Name
            FROM Candidate__c
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 200
        ]) {
            options.add(new OptionWrapper(c.Name, c.Id));
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getInterviewers() {
        List<OptionWrapper> options = new List<OptionWrapper>();
        for (Employee__c e : [
            SELECT Id, Name, Email__c
            FROM Employee__c
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 200
        ]) {
            String label = e.Name + (String.isNotBlank(e.Email__c) ? ' (' + e.Email__c + ')' : '');
            options.add(new OptionWrapper(label, e.Id));
        }
        return options;
    }

    @AuraEnabled
    public static Id scheduleInterview(Interview__c interview) {
        if (interview == null) {
            throwAuraException('Interview record cannot be null.');
        }

        if (interview.Candidate__c == null) {
            throwAuraException('Candidate is required.');
        }
        if (interview.Interviewer__c == null) {
            throwAuraException('Interviewer is required.');
        }
        if (interview.Interview_Date__c == null) {
            throwAuraException('Interview Date is required.');
        }
        if (interview.Start_Time__c == null) {
            throwAuraException('Start Time is required.');
        }
        if (interview.End_Time__c == null) {
            throwAuraException('End Time is required.');
        }

        if (interview.Interview_Date__c < Date.today()) {
            throwAuraException('Interview date cannot be in the past.');
        }

        if (interview.End_Time__c <= interview.Start_Time__c) {
            throwAuraException('End time must be after start time.');
        }

        List<Interview__c> overlapping = [
            SELECT Id
            FROM Interview__c
            WHERE Interviewer__c = :interview.Interviewer__c
              AND Interview_Date__c = :interview.Interview_Date__c
              AND Status__c != 'Cancelled'
              AND Start_Time__c < :interview.End_Time__c
              AND End_Time__c > :interview.Start_Time__c
            WITH USER_MODE
            LIMIT 1
        ];

        if (!overlapping.isEmpty()) {
            throwAuraException('The interviewer is already booked for an interview during this time slot.');
        }

        if (String.isBlank(interview.Status__c)) {
            interview.Status__c = 'Scheduled';
        }

        try {
            insert as user interview;
            return interview.Id;
        } catch (DmlException e) {
            throwAuraException(e.getDmlMessage(0));
        } catch (Exception e) {
            throwAuraException(e.getMessage());
        }
        return null;
    }

    private static void throwAuraException(String msg) {
        AuraHandledException ex = new AuraHandledException(msg);
        ex.setMessage(msg);
        throw ex;
    }
}

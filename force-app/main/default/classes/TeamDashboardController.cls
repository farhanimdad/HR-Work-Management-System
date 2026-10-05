public with sharing class TeamDashboardController {

    public class LeaveRequestWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Id employeeId { get; set; }
        @AuraEnabled public String employeeName { get; set; }
        @AuraEnabled public String leaveTypeName { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String reason { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class LowAttendanceWrapper {
        @AuraEnabled public Id employeeId { get; set; }
        @AuraEnabled public String employeeName { get; set; }
        @AuraEnabled public Integer presentCount { get; set; }
        @AuraEnabled public Integer totalDays { get; set; }
        @AuraEnabled public Decimal attendancePercentage { get; set; }
    }

    public class UpcomingInterviewWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Id candidateId { get; set; }
        @AuraEnabled public String candidateName { get; set; }
        @AuraEnabled public Id interviewerId { get; set; }
        @AuraEnabled public String interviewerName { get; set; }
        @AuraEnabled public Date interviewDate { get; set; }
        @AuraEnabled public Time startTime { get; set; }
        @AuraEnabled public Time endTime { get; set; }
        @AuraEnabled public String round { get; set; }
    }

    private static Set<Id> getTeamEmployeeIds() {
        Set<Id> teamIds = new Set<Id>();
        String userEmail = UserInfo.getUserEmail();

        List<Employee__c> mgrEmps = [
            SELECT Id FROM Employee__c
            WHERE Email__c = :userEmail
            WITH USER_MODE
            LIMIT 1
        ];

        Id mgrId = !mgrEmps.isEmpty() ? mgrEmps[0].Id : null;

        if (mgrId != null) {
            for (Employee__c emp : [
                SELECT Id FROM Employee__c
                WHERE Manager__c = :mgrId
                WITH USER_MODE
            ]) {
                teamIds.add(emp.Id);
            }
        }

        if (teamIds.isEmpty()) {
            for (Employee__c emp : [
                SELECT Id FROM Employee__c
                WITH USER_MODE
                LIMIT 200
            ]) {
                teamIds.add(emp.Id);
            }
        }

        return teamIds;
    }

    @AuraEnabled(cacheable=true)
    public static Decimal getTeamAttendancePercentage() {
        Set<Id> teamEmpIds = getTeamEmployeeIds();
        if (teamEmpIds.isEmpty()) {
            return 0.0;
        }

        Integer m = Date.today().month();
        Integer y = Date.today().year();

        List<AggregateResult> results = [
            SELECT Status__c statusVal, COUNT(Id) cnt
            FROM Attendance__c
            WHERE Employee__c IN :teamEmpIds
              AND CALENDAR_MONTH(Attendence_Date__c) = :m
              AND CALENDAR_YEAR(Attendence_Date__c) = :y
            WITH USER_MODE
            GROUP BY Status__c
        ];

        Integer presentCount = 0;
        Integer totalDays = 0;

        for (AggregateResult ar : results) {
            String st = (String) ar.get('statusVal');
            Integer cnt = Integer.valueOf(ar.get('cnt'));

            totalDays += cnt;
            if (st == 'Present' || st == 'WFH') {
                presentCount += cnt;
            }
        }

        if (totalDays > 0) {
            return (((Decimal) presentCount / totalDays) * 100.0).setScale(1, System.RoundingMode.HALF_UP);
        }
        return 0.0;
    }

    @AuraEnabled(cacheable=true)
    public static List<LeaveRequestWrapper> getPendingLeaveRequests() {
        Set<Id> teamEmpIds = getTeamEmployeeIds();
        List<LeaveRequestWrapper> wrappers = new List<LeaveRequestWrapper>();

        if (teamEmpIds.isEmpty()) {
            return wrappers;
        }

        for (Leave_Request__c lr : [
            SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__r.Name, Start_Date__c, End_Date__c, Reason__c, Status__c
            FROM Leave_Request__c
            WHERE Employee__c IN :teamEmpIds
              AND (Status__c = 'Submitted' OR Status__c = 'Draft' OR Approval_Status__c = 'Pending')
            WITH USER_MODE
            ORDER BY Start_Date__c ASC
            LIMIT 50
        ]) {
            LeaveRequestWrapper w = new LeaveRequestWrapper();
            w.id = lr.Id;
            w.name = lr.Name;
            w.employeeId = lr.Employee__c;
            w.employeeName = lr.Employee__r != null ? lr.Employee__r.Name : 'Unknown';
            w.leaveTypeName = lr.Leave_Type__r != null ? lr.Leave_Type__r.Name : '';
            w.startDate = lr.Start_Date__c;
            w.endDate = lr.End_Date__c;
            w.reason = lr.Reason__c;
            w.status = lr.Status__c;
            wrappers.add(w);
        }

        return wrappers;
    }

    @AuraEnabled(cacheable=true)
    public static List<LowAttendanceWrapper> getEmployeesBelowThreshold() {
        Set<Id> teamEmpIds = getTeamEmployeeIds();
        List<LowAttendanceWrapper> wrappers = new List<LowAttendanceWrapper>();

        if (teamEmpIds.isEmpty()) {
            return wrappers;
        }

        Integer m = Date.today().month();
        Integer y = Date.today().year();

        List<AggregateResult> results = [
            SELECT Employee__c empId, Employee__r.Name empName, Status__c statusVal, COUNT(Id) cnt
            FROM Attendance__c
            WHERE Employee__c IN :teamEmpIds
              AND CALENDAR_MONTH(Attendence_Date__c) = :m
              AND CALENDAR_YEAR(Attendence_Date__c) = :y
            WITH USER_MODE
            GROUP BY Employee__c, Employee__r.Name, Status__c
        ];

        Map<Id, String> empNames = new Map<Id, String>();
        Map<Id, Integer> empPresents = new Map<Id, Integer>();
        Map<Id, Integer> empTotals = new Map<Id, Integer>();

        for (AggregateResult ar : results) {
            Id empId = (Id) ar.get('empId');
            String empName = (String) ar.get('empName');
            String st = (String) ar.get('statusVal');
            Integer cnt = Integer.valueOf(ar.get('cnt'));

            empNames.put(empId, empName);
            Integer currentTotal = empTotals.containsKey(empId) ? empTotals.get(empId) : 0;
            empTotals.put(empId, currentTotal + cnt);

            if (st == 'Present' || st == 'WFH') {
                Integer currentPresent = empPresents.containsKey(empId) ? empPresents.get(empId) : 0;
                empPresents.put(empId, currentPresent + cnt);
            }
        }

        for (Id empId : empTotals.keySet()) {
            Integer total = empTotals.get(empId);
            Integer present = empPresents.containsKey(empId) ? empPresents.get(empId) : 0;
            Decimal pct = (total > 0) ? (((Decimal) present / total) * 100.0).setScale(1, System.RoundingMode.HALF_UP) : 0.0;

            if (pct < 75.0) {
                LowAttendanceWrapper w = new LowAttendanceWrapper();
                w.employeeId = empId;
                w.employeeName = empNames.get(empId);
                w.presentCount = present;
                w.totalDays = total;
                w.attendancePercentage = pct;
                wrappers.add(w);
            }
        }

        return wrappers;
    }

    @AuraEnabled(cacheable=true)
    public static List<UpcomingInterviewWrapper> getUpcomingInterviews() {
        Date today = Date.today();
        Date sevenDaysLater = today.addDays(7);
        Set<Id> teamEmpIds = getTeamEmployeeIds();

        List<UpcomingInterviewWrapper> wrappers = new List<UpcomingInterviewWrapper>();

        for (Interview__c i : [
            SELECT Id, Name, Candidate__c, Candidate__r.Name, Interviewer__c, Interviewer__r.Name, Interview_Date__c, Start_Time__c, End_Time__c, Round__c
            FROM Interview__c
            WHERE Interview_Date__c >= :today
              AND Interview_Date__c <= :sevenDaysLater
              AND (Status__c = 'Scheduled' OR Status__c = null)
              AND (Interviewer__c IN :teamEmpIds OR Interviewer__c = null)
            WITH USER_MODE
            ORDER BY Interview_Date__c ASC, Start_Time__c ASC
            LIMIT 50
        ]) {
            UpcomingInterviewWrapper w = new UpcomingInterviewWrapper();
            w.id = i.Id;
            w.name = i.Name;
            w.candidateId = i.Candidate__c;
            w.candidateName = i.Candidate__r != null ? i.Candidate__r.Name : 'Unassigned Candidate';
            w.interviewerId = i.Interviewer__c;
            w.interviewerName = i.Interviewer__r != null ? i.Interviewer__r.Name : 'Unassigned Interviewer';
            w.interviewDate = i.Interview_Date__c;
            w.startTime = i.Start_Time__c;
            w.endTime = i.End_Time__c;
            w.round = i.Round__c;
            wrappers.add(w);
        }

        return wrappers;
    }
}

public with sharing class AttendanceDashboardController {

    public class AttendanceStatsWrapper {
        @AuraEnabled public Integer presentCount { get; set; }
        @AuraEnabled public Integer absentCount { get; set; }
        @AuraEnabled public Integer leaveCount { get; set; }
        @AuraEnabled public Integer lateCount { get; set; }
        @AuraEnabled public Decimal attendancePercentage { get; set; }
        @AuraEnabled public Integer totalDays { get; set; }

        public AttendanceStatsWrapper() {
            this.presentCount = 0;
            this.absentCount = 0;
            this.leaveCount = 0;
            this.lateCount = 0;
            this.attendancePercentage = 0.0;
            this.totalDays = 0;
        }
    }

    @AuraEnabled(cacheable=true)
    public static AttendanceStatsWrapper getMonthlyStats(Id employeeId, Integer selectedMonth, Integer selectedYear) {
        AttendanceStatsWrapper stats = new AttendanceStatsWrapper();
        if (employeeId == null) {
            return stats;
        }

        Integer m = (selectedMonth != null) ? selectedMonth : Date.today().month();
        Integer y = (selectedYear != null) ? selectedYear : Date.today().year();

        List<AggregateResult> results = [
            SELECT Status__c statusVal, Is_Late__c isLateVal, COUNT(Id) cnt
            FROM Attendance__c
            WHERE Employee__c = :employeeId
              AND CALENDAR_MONTH(Attendence_Date__c) = :m
              AND CALENDAR_YEAR(Attendence_Date__c) = :y
            WITH USER_MODE
            GROUP BY Status__c, Is_Late__c
        ];

        for (AggregateResult ar : results) {
            String st = (String) ar.get('statusVal');
            Boolean isLate = (Boolean) ar.get('isLateVal');
            Integer cnt = Integer.valueOf(ar.get('cnt'));

            stats.totalDays += cnt;

            if (st == 'Present' || st == 'WFH') {
                stats.presentCount += cnt;
            } else if (st == 'Absent') {
                stats.absentCount += cnt;
            } else if (st == 'Leave') {
                stats.leaveCount += cnt;
            } else if (st == 'Half Day') {
                stats.presentCount += cnt;
            }

            if (isLate != null && isLate) {
                stats.lateCount += cnt;
            }
        }

        if (stats.totalDays > 0) {
            stats.attendancePercentage = (((Decimal) stats.presentCount / stats.totalDays) * 100.0).setScale(1, System.RoundingMode.HALF_UP);
        } else {
            stats.attendancePercentage = 0.0;
        }

        return stats;
    }
}

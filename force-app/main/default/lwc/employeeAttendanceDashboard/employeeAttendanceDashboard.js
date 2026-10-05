import { LightningElement, api, wire, track } from 'lwc';
import getMonthlyStats from '@salesforce/apex/AttendanceDashboardController.getMonthlyStats';

export default class EmployeeAttendanceDashboard extends LightningElement {
    @api recordId;

    @track selectedMonth;
    @track selectedYear;
    @track monthYearValue;
    @track monthOptions = [];

    connectedCallback() {
        const today = new Date();
        this.selectedMonth = today.getMonth() + 1;
        this.selectedYear = today.getFullYear();
        this.monthYearValue = `${this.selectedYear}-${this.selectedMonth}`;

        const monthNames = [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        ];

        let options = [];
        for (let i = 0; i < 12; i++) {
            let d = new Date(today.getFullYear(), today.getMonth() - i, 1);
            let m = d.getMonth() + 1;
            let y = d.getFullYear();
            options.push({
                label: `${monthNames[m - 1]} ${y}`,
                value: `${y}-${m}`
            });
        }
        this.monthOptions = options;
    }

    @wire(getMonthlyStats, { employeeId: '$recordId', selectedMonth: '$selectedMonth', selectedYear: '$selectedYear' })
    wiredMonthlyStats;

    get isLoading() {
        return !this.wiredMonthlyStats.data && !this.wiredMonthlyStats.error;
    }

    get hasError() {
        return !!this.wiredMonthlyStats.error;
    }

    get errorMessage() {
        if (this.wiredMonthlyStats.error) {
            if (Array.isArray(this.wiredMonthlyStats.error.body)) {
                return this.wiredMonthlyStats.error.body.map((e) => e.message).join(', ');
            } else if (typeof this.wiredMonthlyStats.error.body?.message === 'string') {
                return this.wiredMonthlyStats.error.body.message;
            }
            return 'An unexpected error occurred while loading attendance statistics.';
        }
        return '';
    }

    get stats() {
        return this.wiredMonthlyStats.data || {};
    }

    get hasData() {
        return this.wiredMonthlyStats.data && this.wiredMonthlyStats.data.totalDays > 0;
    }

    get isEmpty() {
        return this.wiredMonthlyStats.data && this.wiredMonthlyStats.data.totalDays === 0;
    }

    get attendancePercentage() {
        return this.stats.attendancePercentage != null ? this.stats.attendancePercentage : 0;
    }

    handleMonthChange(event) {
        const val = event.detail.value;
        if (val) {
            const parts = val.split('-');
            this.selectedYear = parseInt(parts[0], 10);
            this.selectedMonth = parseInt(parts[1], 10);
            this.monthYearValue = val;
        }
    }
}

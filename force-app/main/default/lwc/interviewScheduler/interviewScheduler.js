import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import HR_ACTIONS_CHANNEL from '@salesforce/messageChannel/HRActions__c';
import getCandidates from '@salesforce/apex/InterviewSchedulerController.getCandidates';
import getInterviewers from '@salesforce/apex/InterviewSchedulerController.getInterviewers';
import scheduleInterview from '@salesforce/apex/InterviewSchedulerController.scheduleInterview';

export default class InterviewScheduler extends LightningElement {
    @wire(MessageContext)
    messageContext;

    subscription = null;
    @track candidateId = '';
    @track interviewerId = '';
    @track interviewDate = '';
    @track startTime = '';
    @track endTime = '';
    @track round = '';
    @track mode = '';
    @track meetingLink = '';
    @track notes = '';

    @track isSaving = false;

    candidateOptions = [];
    interviewerOptions = [];

    roundOptions = [
        { label: 'HR Round', value: 'HR Round' },
        { label: 'Technical Round', value: 'Technical Round' },
        { label: 'Managerial Round', value: 'Managerial Round' },
        { label: 'Final Round', value: 'Final Round' }
    ];

    modeOptions = [
        { label: 'Online', value: 'Online' },
        { label: 'Offline', value: 'Offline' },
        { label: 'Phone', value: 'Phone' }
    ];

    wiredCandidateResult;
    wiredInterviewerResult;

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                HR_ACTIONS_CHANNEL,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    unsubscribeToMessageChannel() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    handleMessage(message) {
        if (message && message.actionName === 'scheduleInterview') {
            const cardEl = this.template.querySelector('lightning-card');
            if (cardEl && cardEl.scrollIntoView) {
                cardEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
            setTimeout(() => {
                const candidateField = this.template.querySelector('[data-id="candidateField"]');
                if (candidateField && typeof candidateField.focus === 'function') {
                    candidateField.focus();
                }
            }, 300);
        }
    }

    @wire(getCandidates)
    wiredCandidates(result) {
        this.wiredCandidateResult = result;
        if (result.data) {
            this.candidateOptions = result.data;
        } else if (result.error) {
            this.candidateOptions = [];
        }
    }

    @wire(getInterviewers)
    wiredInterviewers(result) {
        this.wiredInterviewerResult = result;
        if (result.data) {
            this.interviewerOptions = result.data;
        } else if (result.error) {
            this.interviewerOptions = [];
        }
    }

    get minDate() {
        // Today's date in YYYY-MM-DD
        const today = new Date();
        return today.toISOString().split('T')[0];
    }

    get isLoading() {
        return (
            !this.wiredCandidateResult?.data &&
            !this.wiredCandidateResult?.error &&
            !this.wiredInterviewerResult?.data &&
            !this.wiredInterviewerResult?.error
        );
    }

    get hasWireError() {
        return !!this.wiredCandidateResult?.error || !!this.wiredInterviewerResult?.error;
    }

    get wireErrorMessage() {
        if (this.wiredCandidateResult?.error) {
            return 'Failed to load candidates.';
        }
        if (this.wiredInterviewerResult?.error) {
            return 'Failed to load interviewers.';
        }
        return '';
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.value;

        if (field === 'candidate') this.candidateId = value;
        else if (field === 'interviewer') this.interviewerId = value;
        else if (field === 'interviewDate') this.interviewDate = value;
        else if (field === 'startTime') this.startTime = value;
        else if (field === 'endTime') this.endTime = value;
        else if (field === 'round') this.round = value;
        else if (field === 'mode') this.mode = value;
        else if (field === 'meetingLink') this.meetingLink = value;
        else if (field === 'notes') this.notes = value;

        // Clear custom validity when user modifies the field
        if (event.target.setCustomValidity) {
            event.target.setCustomValidity('');
            event.target.reportValidity();
        }
    }

    validateForm() {
        let isValid = true;

        const dateField = this.template.querySelector('[data-id="dateField"]');
        const startTimeField = this.template.querySelector('[data-id="startTimeField"]');
        const endTimeField = this.template.querySelector('[data-id="endTimeField"]');

        // Reset custom validities
        if (dateField) dateField.setCustomValidity('');
        if (endTimeField) endTimeField.setCustomValidity('');

        // 1. Date not in past check
        if (this.interviewDate) {
            const selectedDate = new Date(this.interviewDate + 'T00:00:00');
            const today = new Date();
            today.setHours(0, 0, 0, 0);

            if (selectedDate < today) {
                if (dateField) {
                    dateField.setCustomValidity('Interview date cannot be in the past.');
                }
                isValid = false;
            }
        }

        // 2. End time after start time check
        if (this.startTime && this.endTime) {
            if (this.endTime <= this.startTime) {
                if (endTimeField) {
                    endTimeField.setCustomValidity('End time must be after start time.');
                }
                isValid = false;
            }
        }

        // 3. Check standard reportValidity on all inputs
        const allInputs = [...this.template.querySelectorAll('lightning-combobox, lightning-input, lightning-textarea')];
        allInputs.forEach((input) => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });

        return isValid;
    }

    handleSave() {
        if (!this.validateForm()) {
            this.showToast('Validation Error', 'Please correct the errors in the form before submitting.', 'error');
            return;
        }

        this.isSaving = true;

        // Format time values for Apex Time binding if needed
        let formattedStartTime = this.startTime;
        if (formattedStartTime && formattedStartTime.length === 5) {
            formattedStartTime += ':00.000Z';
        }
        let formattedEndTime = this.endTime;
        if (formattedEndTime && formattedEndTime.length === 5) {
            formattedEndTime += ':00.000Z';
        }

        const interviewRecord = {
            Candidate__c: this.candidateId,
            Interviewer__c: this.interviewerId,
            Interview_Date__c: this.interviewDate,
            Start_Time__c: formattedStartTime,
            End_Time__c: formattedEndTime,
            Round__c: this.round,
            Mode__c: this.mode,
            Meeting_Link__c: this.meetingLink,
            Notes__c: this.notes,
            Status__c: 'Scheduled'
        };

        scheduleInterview({ interview: interviewRecord })
            .then((newRecordId) => {
                this.isSaving = false;
                this.showToast('Success', 'Interview scheduled successfully!', 'success');

                // Dispatch custom event interviewscheduled
                this.dispatchEvent(
                    new CustomEvent('interviewscheduled', {
                        detail: { recordId: newRecordId },
                        bubbles: true,
                        composed: true
                    })
                );

                this.handleReset();
            })
            .catch((error) => {
                this.isSaving = false;
                let errorMsg = 'An unexpected error occurred while scheduling the interview.';
                if (error && error.body && error.body.message) {
                    errorMsg = error.body.message;
                } else if (typeof error === 'string') {
                    errorMsg = error;
                }
                this.showToast('Error Scheduling Interview', errorMsg, 'error');
            });
    }

    handleReset() {
        this.candidateId = '';
        this.interviewerId = '';
        this.interviewDate = '';
        this.startTime = '';
        this.endTime = '';
        this.round = '';
        this.mode = '';
        this.meetingLink = '';
        this.notes = '';

        const allInputs = [...this.template.querySelectorAll('lightning-combobox, lightning-input, lightning-textarea')];
        allInputs.forEach((input) => {
            if (input.setCustomValidity) {
                input.setCustomValidity('');
            }
            if (input.reportValidity) {
                input.reportValidity();
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}

import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import JOB_APP_OBJECT from '@salesforce/schema/Job_Application__c';
import STAGE_FIELD from '@salesforce/schema/Job_Application__c.stage__c';
import ID_FIELD from '@salesforce/schema/Job_Application__c.Id';

export default class CandidatePipeline extends LightningElement {
    @api recordId;

    @track stageOptions = [];
    @track recordData = null;
    @track error = null;
    @track isUpdating = false;

    objectInfoData = null;

    @wire(getObjectInfo, { objectApiName: JOB_APP_OBJECT })
    wiredObjectInfo({ error, data }) {
        if (data) {
            this.objectInfoData = data;
        } else if (error) {
            this.error = error;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfoData.defaultRecordTypeId',
        fieldApiName: STAGE_FIELD
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.stageOptions = data.values.map((v) => ({
                label: v.label,
                value: v.value
            }));
        } else if (error) {
            this.error = error;
            this.stageOptions = [];
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [STAGE_FIELD] })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordData = data;
            this.error = null;
        } else if (error) {
            this.error = error;
            this.recordData = null;
        }
    }

    get currentStage() {
        return getFieldValue(this.recordData, STAGE_FIELD) || '';
    }

    get isLoading() {
        return !this.recordData && !this.error && this.stageOptions.length === 0;
    }

    get hasError() {
        return !!this.error;
    }

    get errorMessage() {
        if (this.error) {
            if (this.error.body && this.error.body.message) {
                return this.error.body.message;
            }
            if (this.error.message) {
                return this.error.message;
            }
            return 'An error occurred while loading record stage details.';
        }
        return '';
    }

    get isUpdateable() {
        if (this.objectInfoData) {
            return this.objectInfoData.updateable;
        }
        return true;
    }

    get isFinalStage() {
        const finalStages = ['Joined', 'Rejected', 'Offer Accepted', 'Offer Declined'];
        return finalStages.includes(this.currentStage);
    }

    get isNextDisabled() {
        if (this.isUpdating || !this.isUpdateable || this.isFinalStage) {
            return true;
        }
        const currentIndex = this.stageOptions.findIndex((opt) => opt.value === this.currentStage);
        return currentIndex === -1 || currentIndex >= this.stageOptions.length - 1;
    }

    get isRejectDisabled() {
        if (this.isUpdating || !this.isUpdateable || this.currentStage === 'Rejected' || this.currentStage === 'Joined') {
            return true;
        }
        return false;
    }

    handleNextStage() {
        const currentIndex = this.stageOptions.findIndex((opt) => opt.value === this.currentStage);
        if (currentIndex !== -1 && currentIndex < this.stageOptions.length - 1) {
            const nextStage = this.stageOptions[currentIndex + 1].value;
            this.updateStage(nextStage);
        }
    }

    handleMarkRejected() {
        this.updateStage('Rejected');
    }

    updateStage(newStage) {
        this.isUpdating = true;
        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[STAGE_FIELD.fieldApiName] = newStage;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {
                this.isUpdating = false;
                this.showToast('Success', `Candidate stage updated to "${newStage}" successfully!`, 'success');
            })
            .catch((err) => {
                this.isUpdating = false;
                let msg = 'Failed to update stage.';
                if (err && err.body && err.body.message) {
                    msg = err.body.message;
                } else if (err && err.message) {
                    msg = err.message;
                }
                this.showToast('Error Updating Stage', msg, 'error');
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

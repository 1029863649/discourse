import { popupAjaxError } from 'discourse/lib/ajax-error';
import { urlValid } from 'discourse/lib/utilities';
import computed from 'ember-addons/ember-computed-decorators';
import InputValidation from 'discourse/models/input-validation';

export default Ember.Controller.extend({
  needs: ['adminWebHooks'],
  eventTypes: Em.computed.alias('controllers.adminWebHooks.eventTypes'),
  defaultEventTypes: Em.computed.alias('controllers.adminWebHooks.defaultEventTypes'),
  contentTypes: Em.computed.alias('controllers.adminWebHooks.contentTypes'),

  @computed('model.isSaving', 'saved', 'saveButtonDisabled')
  savingStatus(isSaving, saved, saveButtonDisabled) {
    if (isSaving) {
      return I18n.t('saving');
    } else if (!saveButtonDisabled && saved) {
      return I18n.t('saved');
    }
    // Use side effect of validation to clear saved text
    this.set('saved', false);
    return '';
  },

  @computed('model.isNew')
  saveButtonText(isNew) {
    return isNew ? I18n.t('admin.web_hooks.create') : I18n.t('admin.web_hooks.save');
  },

  @computed('model.payload_url')
  urlValidation(url) {
    // If blank, fail without a reason
    if (Ember.isEmpty(url)) {
      return InputValidation.create({
        failed: true
      });
    }

    if (!urlValid(url)) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('admin.web_hooks.payload_url_invalid')
      });
    }
  },

  @computed('model.secret')
  secretValidation(secret) {
    if (!Ember.isEmpty(secret)) {
      if (secret.indexOf(' ') !== -1) {
        return InputValidation.create({
          failed: true,
          reason: I18n.t('admin.web_hooks.secret_invalid')
        });
      }

      if (secret.length < 12) {
         return InputValidation.create({
          failed: true,
          reason: I18n.t('admin.web_hooks.secret_too_short')
        });
      }
    }
  },

  @computed('model.wildcard_web_hook', 'model.web_hook_event_types.[]')
  eventTypeValidation(isWildcard, eventTypes) {
    if (!isWildcard && Ember.isEmpty(eventTypes)) {
      return InputValidation.create({
        failed: true,
        reason: I18n.t('admin.web_hooks.event_type_missing')
      });
    }
  },

  @computed('model.isSaving', 'urlValidation', 'secretValidation', 'eventTypeValidation')
  saveButtonDisabled(isSaving, urlValidation, secretValidation, eventTypeValidation) {
    return isSaving ? false : urlValidation || secretValidation || eventTypeValidation;
  },

  actions: {
    save() {
      this.set('saved', false);

      const model = this.get('model');
      return model.save().then(() => {
        this.set('saved', true);
        this.get('controllers.adminWebHooks').get('model').addObject(model);
      }).catch(popupAjaxError);
    },

    destroy() {
      return bootbox.confirm(I18n.t('admin.web_hooks.delete_confirm'), I18n.t('no_value'), I18n.t('yes_value'), result => {
        if (result) {
          const model = this.get('model');
          model.destroyRecord().then(() => {
            this.get('controllers.adminWebHooks').get('model').removeObject(model);
            this.transitionToRoute('adminWebHooks');
          }).catch(popupAjaxError);
        }
      });
    }
  }
});

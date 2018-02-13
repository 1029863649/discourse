import { ajax } from 'discourse/lib/ajax';
import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { escapeExpression } from 'discourse/lib/utilities';
import { extractError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend(ModalFunctionality, {
  offerHelp: null,
  helpSeen: false,

  @computed('accountEmailOrUsername', 'disabled')
  submitDisabled(accountEmailOrUsername, disabled) {
    return Ember.isEmpty((accountEmailOrUsername || '').trim()) || disabled;
  },

  onShow() {
    if ($.cookie('email')) {
      this.set('accountEmailOrUsername', $.cookie('email'));
    }
  },

  actions: {
    ok() {
      this.send('closeModal');
    },

    help() {
      this.setProperties({ offerHelp: I18n.t('forgot_password.help'), helpSeen: true });
    },

    resetPassword() {
      return this._submit('/session/forgot_password', 'forgot_password.complete');
    },

    emailLogin() {
      return this._submit('/u/email-login', 'email_login.complete');
    }
  },

  _submit(route, translationKey) {
    if (this.get('submitDisabled')) return false;
    this.set('disabled', true);

    ajax(route, {
      data: { login: this.get('accountEmailOrUsername').trim() },
      type: 'POST'
    }).then(data => {
      const escaped = escapeExpression(this.get('accountEmailOrUsername'));
      const isEmail = this.get('accountEmailOrUsername').match(/@/);
      let key = `${translationKey}_${isEmail ? 'email' : 'username'}`;
      let extraClass;

      if (data.user_found === true) {
        key += '_found';
        this.set('accountEmailOrUsername', '');
        this.set('offerHelp', I18n.t(key, { email: escaped, username: escaped }));
      } else {
        if (data.user_found === false) {
          key += '_not_found';
          extraClass = 'error';
        }

        this.flash(I18n.t(key, { email: escaped, username: escaped }), extraClass);
      }
    }).catch(e => {
      this.flash(extractError(e), 'error');
    }).finally(() => {
      this.set('disabled', false);
    });

    return false;
  },
});

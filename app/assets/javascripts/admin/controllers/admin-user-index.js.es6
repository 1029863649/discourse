import { ajax } from 'discourse/lib/ajax';
import CanCheckEmails from 'discourse/mixins/can-check-emails';
import { propertyNotEqual, setting } from 'discourse/lib/computed';
import { userPath } from 'discourse/lib/url';

export default Ember.Controller.extend(CanCheckEmails, {
  editingUsername: false,
  editingName: false,
  editingTitle: false,
  originalPrimaryGroupId: null,
  availableGroups: null,
  userTitleValue: null,

  showApproval: setting('must_approve_users'),
  showBadges: setting('enable_badges'),

  primaryGroupDirty: propertyNotEqual('originalPrimaryGroupId', 'model.primary_group_id'),

  automaticGroups: function() {
    return this.get("model.automaticGroups").map((g) => g.name).join(", ");
  }.property("model.automaticGroups"),

  userFields: function() {
    const siteUserFields = this.site.get('user_fields'),
          userFields = this.get('model.user_fields');

    if (!Ember.isEmpty(siteUserFields)) {
      return siteUserFields.map(function(uf) {
        let value = userFields ? userFields[uf.get('id').toString()] : null;
        return { name: uf.get('name'), value: value };
      });
    }
    return [];
  }.property('model.user_fields.[]'),

  actions: {

    impersonate() { return this.get("model").impersonate(); },
    logOut() { return this.get("model").logOut(); },
    resetBounceScore() { return this.get("model").resetBounceScore(); },
    refreshBrowsers() { return this.get("model").refreshBrowsers(); },
    approve() { return this.get("model").approve(); },
    deactivate() { return this.get("model").deactivate(); },
    sendActivationEmail() { return this.get("model").sendActivationEmail(); },
    activate() { return this.get("model").activate(); },
    revokeAdmin() { return this.get("model").revokeAdmin(); },
    grantAdmin() { return this.get("model").grantAdmin(); },
    revokeModeration() { return this.get("model").revokeModeration(); },
    grantModeration() { return this.get("model").grantModeration(); },
    saveTrustLevel() { return this.get("model").saveTrustLevel(); },
    restoreTrustLevel() { return this.get("model").restoreTrustLevel(); },
    lockTrustLevel(locked) { return this.get("model").lockTrustLevel(locked); },
    unsuspend() { return this.get("model").unsuspend(); },
    unblock() { return this.get("model").unblock(); },
    block() { return this.get("model").block(); },
    deleteAllPosts() { return this.get("model").deleteAllPosts(); },
    anonymize() { return this.get('model').anonymize(); },
    destroy() { return this.get('model').destroy(); },

    toggleUsernameEdit() {
      this.set('userUsernameValue', this.get('model.username'));
      this.toggleProperty('editingUsername');
    },

    saveUsername() {
      const self = this;
      const old_username = self.get('model.username');

      self.set('model.username', self.get('userUsernameValue'));
      return ajax(`/users/${old_username.toLowerCase()}/preferences/username`, {
        data: { new_username: this.get('userUsernameValue') },
        type: 'PUT'
      }).catch(function(e) {
        self.set('model.username', old_username);
        bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
      }).finally(function() {
        self.toggleProperty('editingUsername');
      });
    },

    toggleNameEdit() {
        this.set('userNameValue', this.get('model.name'));
        this.toggleProperty('editingName');
    },

    saveName() {
      const self = this;
      const old_name = self.get('model.name');

      self.set('model.name', self.get('userNameValue'));
      return ajax(userPath(`${this.get('model.username').toLowerCase()}.json`), {
        data: {name: this.get('userNameValue')},
        type: 'PUT'
      }).catch(function(e) {
        self.set('model.name', old_name);
        bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
      }).finally(function() {
        self.toggleProperty('editingName');
      });
    },

    toggleTitleEdit() {
      this.set('userTitleValue', this.get('model.title'));
      this.toggleProperty('editingTitle');
    },

    saveTitle() {
      const self = this;
      const old_title = self.get('userTitleValue');

      self.set('model.title', self.get('userTitleValue'));
      return ajax(userPath(`${this.get('model.username').toLowerCase()}.json`), {
        data: {title: this.get('userTitleValue')},
        type: 'PUT'
      }).catch(function(e) {
        self.set('model.title', old_title);
        bootbox.alert(I18n.t("generic_error_with_reason", {error: "http: " + e.status + " - " + e.body}));
      }).finally(function() {
        self.toggleProperty('editingTitle');
      });
    },

    generateApiKey() {
      this.get('model').generateApiKey();
    },

    groupAdded(added) {
      this.get('model').groupAdded(added).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    groupRemoved(groupId) {
      this.get('model').groupRemoved(groupId).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    savePrimaryGroup() {
      const self = this;

      return ajax("/admin/users/" + this.get('model.id') + "/primary_group", {
        type: 'PUT',
        data: {primary_group_id: this.get('model.primary_group_id')}
      }).then(function () {
        self.set('originalPrimaryGroupId', self.get('model.primary_group_id'));
      }).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    },

    resetPrimaryGroup() {
      this.set('model.primary_group_id', this.get('originalPrimaryGroupId'));
    },

    regenerateApiKey() {
      const self = this;

      bootbox.confirm(
        I18n.t("admin.api.confirm_regen"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(result) {
          if (result) { self.get('model').generateApiKey(); }
        }
      );
    },

    revokeApiKey() {
      const self = this;

      bootbox.confirm(
        I18n.t("admin.api.confirm_revoke"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function(result) {
          if (result) { self.get('model').revokeApiKey(); }
        }
      );
    }
  }

});

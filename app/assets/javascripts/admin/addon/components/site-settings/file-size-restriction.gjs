import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import FileSizeInput from "admin/components/file-size-input";
import SettingValidationMessage from "admin/components/setting-validation-message";

export default class FileSizeRestriction extends Component {
  @tracked _validationMessage;

  constructor() {
    super(...arguments);

    this._validationMessage = this.args.validationMessage;
  }

  @action
  updateValidationMessage(message) {
    this._validationMessage = message;
  }

  get validationMessage() {
    return this._validationMessage ?? this.args.validationMessage;
  }

  <template>
    <FileSizeInput
      @sizeValueKB={{@value}}
      @onChangeSize={{fn (mut @value)}}
      @updateValidationMessage={{this.updateValidationMessage}}
      @min={{if @setting.min @setting.min null}}
      @max={{if @setting.max @setting.max null}}
      @message={{this.validationMessage}}
    />

    <SettingValidationMessage @message={{this.validationMessage}} />
    <div class="desc">{{htmlSafe @setting.description}}</div>
  </template>
}

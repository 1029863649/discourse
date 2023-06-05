import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ModalContainer extends Component {
  @service modal;

  @action
  closeModal(initiatedBy) {
    this.modal.close(initiatedBy);
  }
}

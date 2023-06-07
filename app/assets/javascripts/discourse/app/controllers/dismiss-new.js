import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";

export default class DismissNewController extends Controller.extend(
  ModalFunctionality
) {
  @action
  dismiss() {
    this.dismissCallback();
    this.send("closeModal");
  }
}

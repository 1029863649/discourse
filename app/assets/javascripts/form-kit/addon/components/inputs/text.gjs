import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import FieldWrapper from "form-kit/components/field-wrapper";
import InputWrapper from "form-kit/components/input-wrapper";
import Node from "form-kit/lib/node";
import Label from "../label";
import Meta from "../meta";

export default class Text extends Component {
  node = new Node(
    {
      type: "input",
      value: this.args.value,
      name: this.args.name,
      parent: this.args.node,
    },
    {
      label: this.args.label,
      help: this.args.help,
      validation: this.args.validation,
      optional: this.args.optional,
      horizontal: this.args.horizontal,
    }
  );

  constructor() {
    super(...arguments);

    next(() => {
      this.args.node.add(this.node);

      this.node.validate();
    });
  }

  @action
  onInput(event) {
    this.node.input(event.target.value);
    this.node.validate();
  }

  <template>
    {{#if this.node.props.label}}
      <Label @node={{this.node}} />
    {{/if}}

    <Input
      @type="text"
      @value={{readonly this.node.config.value}}
      name={{this.node.config.name}}
      class="d-form-field__input"
      {{on "input" this.onInput}}
      ...attributes
    />

    <Meta @node={{this.node}} />
  </template>
}

import Component from "@glimmer/component";
import FormText from "form-kit/components/text";

export default class FKContainer extends Component {
  <template>
    <div class="d-form__container" ...attributes>
      {{#if @title}}
        <span class="d-form__container-title">
          {{@title}}
        </span>
      {{/if}}

      {{#if @subtitle}}
        <FormText class="d-form__container-subtitle">{{@subtitle}}</FormText>
      {{/if}}

      <div class="d-form__container-content">
        {{yield}}
      </div>
    </div>
  </template>
}

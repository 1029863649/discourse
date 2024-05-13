import concatClass from "discourse/helpers/concat-class";

const Row = <template>
  <div
    class={{concatClass
      "d-form__row"
      (if @node.context.horizontal "--horizontal")
    }}
  >
    {{yield}}
  </div>
</template>;

export default Row;

import guid from "pretty-text/guid";

/**
 * @typedef {Object} ClassModification
 * @property {Class} latestClass
 * @property {Class} boundaryClass
 * @property {Map<string,function>} baseStaticMethods
 */

/** @type Map<class, ClassModification> */
export const classModifications = new Map();

export const classModificationsKey = Symbol("CLASS_MODIFICATIONS_KEY");
export const stopSymbol = Symbol("STOP_SYMBOL");

export default function allowClassModifications(OriginalClass) {
  OriginalClass[classModificationsKey] = guid();

  // TODO: the following class and the boundary class could be merged?
  return class extends OriginalClass {
    constructor() {
      // If the modified constructor chain finished,
      // run the original implementation
      if (arguments[arguments.length - 1] === stopSymbol) {
        super(...arguments);
        return;
      }

      // ...otherwise invoke the constructor of the last modification
      const id = OriginalClass[classModificationsKey];
      const FinalClass =
        classModifications.get(id)?.latestClass || OriginalClass;

      return new FinalClass(...arguments);
    }
  };
}

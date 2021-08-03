import Mixin from "@ember/object/mixin";
import { deepMerge } from "discourse-common/lib/object";
import UppyChecksum from "discourse/lib/uppy-checksum-plugin";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import Uppy from "@uppy/core";
import DropTarget from "@uppy/drop-target";
import XHRUpload from "@uppy/xhr-upload";
import { warn } from "@ember/debug";
import I18n from "I18n";
import { next, run } from "@ember/runloop";
import getURL from "discourse-common/lib/get-url";
import { clipboardHelpers } from "discourse/lib/utilities";
import { observes, on } from "discourse-common/utils/decorators";
import {
  bindFileInputChangeListener,
  displayErrorForUpload,
  getUploadMarkdown,
  validateUploadedFile,
} from "discourse/lib/uploads";
import { cacheShortUploadUrl } from "pretty-text/upload-short-url";

// Note: This mixin is used _in addition_ to the ComposerUpload mixin
// on the composer-editor component. It overrides some, but not all,
// functions created by ComposerUpload. Eventually this will supplant
// ComposerUpload, but until then only the functions that need to be
// overridden to use uppy will be overridden, so as to not go out of
// sync with the main ComposerUpload functionality by copying unchanging
// functions.
//
// Some examples are uploadPlaceholder, the main properties e.g. uploadProgress,
// and the most important _bindUploadTarget which handles all the main upload
// functionality and event binding.
//
export default Mixin.create({
  @observes("composer.uploadCancelled")
  _cancelUpload() {
    if (!this.get("composer.uploadCancelled")) {
      return;
    }
    this.set("composer.uploadCancelled", false);
    this.set("userCancelled", true);

    this.uppyInstance.cancelAll();
  },

  @on("willDestroyElement")
  _unbindUploadTarget() {
    this._processingUploads = 0;
    $("#reply-control .mobile-file-upload").off("click.uploader");
    this.messageBus.unsubscribe("/uploads/composer");

    if (this.fileInputEventListener && this.fileInputEl) {
      this.fileInputEl.removeEventListener(
        "change",
        this.fileInputEventListener
      );
    }

    if (this.pasteEventListener && this.element) {
      this.element.removeEventListener("paste", this.pasteEventListener);
    }
  },

  _bindUploadTarget() {
    this.placeholders = {};
    this.fileInputEl = document.getElementById("file-uploader");
    const isPrivateMessage = this.get("composer.privateMessage");

    this._unbindUploadTarget();
    this._bindFileInputChangeListener();
    this._bindPasteListener();
    this._bindMobileUploadButton();

    this.set(
      "uppyInstance",
      new Uppy({
        id: "composer-uppy",
        autoProceed: true,

        // need to use upload_type because uppy overrides type with the
        // actual file type
        meta: deepMerge({ upload_type: "composer" }, this.data || {}),

        onBeforeFileAdded: (currentFile) => {
          const validationOpts = {
            user: this.currentUser,
            siteSettings: this.siteSettings,
            isPrivateMessage,
            allowStaffToUploadAnyFileInPm: this.siteSettings
              .allow_staff_to_upload_any_file_in_pm,
          };

          const isUploading = validateUploadedFile(currentFile, validationOpts);

          run(() => {
            this.setProperties({ uploadProgress: 0, isUploading });
          });

          return isUploading;
        },

        onBeforeUpload: (files) => {
          const fileCount = Object.keys(files).length;
          const maxFiles = this.siteSettings.simultaneous_uploads;

          // Limit the number of simultaneous uploads
          if (maxFiles > 0 && fileCount > maxFiles) {
            bootbox.alert(
              I18n.t("post.errors.too_many_dragged_and_dropped_files", {
                count: maxFiles,
              })
            );
            this._reset();
            return false;
          }
        },
      })
    );

    this.uppyInstance.use(DropTarget, { target: this.element });
    this.uppyInstance.use(UppyChecksum, { capabilities: this.capabilities });
    this._useXHRUploads();

    // TODO
    // upload handlers
    this.uppyInstance.on("file-added", (file) => {
      if (isPrivateMessage) {
        file.meta.for_private_message = true;
      }
    });

    this.uppyInstance.on("progress", (progress) => {
      this.set("uploadProgress", progress);
    });

    this.uppyInstance.on("upload", (data) => {
      const files = data.fileIDs.map((fileId) =>
        this.uppyInstance.getFile(fileId)
      );
      files.forEach((file) => {
        const placeholder = this._uploadPlaceholder(file);
        this.placeholders[file.id] = {
          uploadPlaceholder: placeholder,
        };
        this.appEvents.trigger("composer:insert-text", placeholder);
      });
    });

    this.uppyInstance.on("upload-success", (file, response) => {
      let upload = response.body;
      const markdown = this.uploadMarkdownResolvers.reduce(
        (md, resolver) => resolver(upload) || md,
        getUploadMarkdown(upload)
      );

      cacheShortUploadUrl(upload.short_url, upload);

      this.appEvents.trigger(
        "composer:replace-text",
        this.placeholders[file.id].uploadPlaceholder.trim(),
        markdown
      );

      this._resetUpload(file, { removePlaceholder: false });
    });

    this.uppyInstance.on("upload-error", (file) => {
      run(() => {
        this._resetUpload(file, { removePlaceholder: true });

        if (!this.userCancelled) {
          displayErrorForUpload(file, this.siteSettings, file.name);
        }
      });
    });

    this.uppyInstance.on("complete", () => {
      this._reset();
    });

    this.uppyInstance.on("cancel-all", () => {
      // uppyInstance.reset() also fires cancel-all, so we want to
      // only do the manual cancelling work if the user clicked cancel
      if (this.userCancelled) {
        Object.values(this.placeholders).forEach((data) => {
          this.appEvents.trigger(
            "composer:replace-text",
            data.uploadPlaceholder,
            ""
          );
        });

        this.set("userCancelled", false);
        this._reset();
      }
    });

    this._setupPreprocessing();
  },

  _setupPreprocessing() {
    Object.keys(this.uploadProcessorActions).forEach((action) => {
      switch (action) {
        case "optimizeJPEG":
          this.uppyInstance.use(UppyMediaOptimization, {
            optimizeFn: this.uploadProcessorActions[action],
          });
          break;
      }
    });

    this.uppyInstance.on("preprocess-progress", (file) => {
      let placeholderData = this.placeholders[file.id];
      placeholderData.processingPlaceholder = `[${I18n.t(
        "processing_filename",
        {
          filename: file.name,
        }
      )}]()\n`;

      this.appEvents.trigger(
        "composer:replace-text",
        placeholderData.uploadPlaceholder,
        placeholderData.processingPlaceholder
      );
      this._processingUploads++;
      this.setProperties({
        isProcessingUpload: true,
        isCancellable: false,
      });
    });

    this.uppyInstance.on("preprocess-complete", (file) => {
      run(() => {
        let placeholderData = this.placeholders[file.id];
        this.appEvents.trigger(
          "composer:replace-text",
          placeholderData.processingPlaceholder,
          placeholderData.uploadPlaceholder
        );
        this._processingUploads--;

        if (this._processingUploads === 0) {
          this.setProperties({
            isProcessingUpload: false,
            isCancellable: true,
          });
        }
      });
    });
  },

  _uploadFilenamePlaceholder(file) {
    const filename = this._filenamePlaceholder(file);

    // when adding two separate files with the same filename search for matching
    // placeholder already existing in the editor ie [Uploading: test.png...]
    // and add order nr to the next one: [Uploading: test.png(1)...]
    const escapedFilename = filename.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regexString = `\\[${I18n.t("uploading_filename", {
      filename: escapedFilename + "(?:\\()?([0-9])?(?:\\))?",
    })}\\]\\(\\)`;
    const globalRegex = new RegExp(regexString, "g");
    const matchingPlaceholder = this.get("composer.reply").match(globalRegex);
    if (matchingPlaceholder) {
      // get last matching placeholder and its consecutive nr in regex
      // capturing group and apply +1 to the placeholder
      const lastMatch = matchingPlaceholder[matchingPlaceholder.length - 1];
      const regex = new RegExp(regexString);
      const orderNr = regex.exec(lastMatch)[1]
        ? parseInt(regex.exec(lastMatch)[1], 10) + 1
        : 1;
      const filenameWithOrderNr = `${filename}(${orderNr})`;
      return filenameWithOrderNr;
    }

    return filename;
  },

  _uploadPlaceholder(file) {
    const clipboard = I18n.t("clipboard");
    const uploadFilenamePlaceholder = this._uploadFilenamePlaceholder(file);
    const filename = uploadFilenamePlaceholder
      ? uploadFilenamePlaceholder
      : clipboard;

    let placeholder = `[${I18n.t("uploading_filename", { filename })}]()\n`;
    if (!this._cursorIsOnEmptyLine()) {
      placeholder = `\n${placeholder}`;
    }

    return placeholder;
  },

  _useXHRUploads() {
    this.uppyInstance.use(XHRUpload, {
      endpoint: getURL(`/uploads.json?client_id=${this.messageBus.clientId}`),
      headers: {
        "X-CSRF-Token": this.session.get("csrfToken"),
      },
    });
  },

  _reset() {
    this.uppyInstance && this.uppyInstance.reset();
    this.setProperties({
      uploadProgress: 0,
      isUploading: false,
      isProcessingUpload: false,
      isCancelleble: false,
    });
  },

  _resetUpload(file, removePlaceholder) {
    next(() => {
      if (removePlaceholder) {
        this.appEvents.trigger(
          "composer:replace-text",
          this.placeholders[file.id].uploadPlaceholder,
          ""
        );
      }
    });
  },

  _bindFileInputChangeListener() {
    this.fileInputEventListener = bindFileInputChangeListener(
      this.fileInputEl,
      this._addFile.bind(this)
    );
  },

  _bindPasteListener() {
    this.pasteEventListener = this.element.addEventListener(
      "paste",
      (event) => {
        if (!$(".d-editor-input").is(":focus")) {
          return;
        }

        const { canUpload, canPasteHtml, types } = clipboardHelpers(event, {
          siteSettings: this.siteSettings,
          canUpload: true,
        });

        if (!canUpload || canPasteHtml || types.includes("text/plain")) {
          event.preventDefault();
          return;
        }

        if (event && event.clipboardData && event.clipboardData.files) {
          [...event.clipboardData.files].forEach(this._addFile.bind(this));
        }
      }
    );
  },

  _addFile(file) {
    try {
      this.uppyInstance.addFile({
        source: `${this.id} file input`,
        name: file.name,
        type: file.type,
        data: file,
      });
    } catch (err) {
      warn(`error adding files to uppy: ${err}`, {
        id: "discourse.upload.uppy-add-files-error",
      });
    }
  },

  showUploadSelector(toolbarEvent) {
    this.send("showUploadSelector", toolbarEvent);
  },
});

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: function (engineInitializer) {
    engineInitializer.initializeEngine({
      renderer: "html",
    }).then(function (appRunner) {
      appRunner.runApp();
    });
  },
});

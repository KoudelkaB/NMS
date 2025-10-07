// Compiles a dart2wasm-generated main module from `source` which can then
// instantiatable via the `instantiate` method.
//
// `source` needs to be a `Response` object (or promise thereof) e.g. created
// via the `fetch()` JS API.
export async function compileStreaming(source) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(
      await WebAssembly.compileStreaming(source, builtins), builtins);
}

// Compiles a dart2wasm-generated wasm modules from `bytes` which is then
// instantiatable via the `instantiate` method.
export async function compile(bytes) {
  const builtins = {builtins: ['js-string']};
  return new CompiledApp(await WebAssembly.compile(bytes, builtins), builtins);
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export async function instantiate(modulePromise, importObjectPromise) {
  var moduleOrCompiledApp = await modulePromise;
  if (!(moduleOrCompiledApp instanceof CompiledApp)) {
    moduleOrCompiledApp = new CompiledApp(moduleOrCompiledApp);
  }
  const instantiatedApp = await moduleOrCompiledApp.instantiate(await importObjectPromise);
  return instantiatedApp.instantiatedModule;
}

// DEPRECATED: Please use `compile` or `compileStreaming` to get a compiled app,
// use `instantiate` method to get an instantiated app and then call
// `invokeMain` to invoke the main function.
export const invoke = (moduleInstance, ...args) => {
  moduleInstance.exports.$invokeMain(args);
}

class CompiledApp {
  constructor(module, builtins) {
    this.module = module;
    this.builtins = builtins;
  }

  // The second argument is an options object containing:
  // `loadDeferredWasm` is a JS function that takes a module name matching a
  //   wasm file produced by the dart2wasm compiler and returns the bytes to
  //   load the module. These bytes can be in either a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`.
  // `loadDynamicModule` is a JS function that takes two string names matching,
  //   in order, a wasm file produced by the dart2wasm compiler during dynamic
  //   module compilation and a corresponding js file produced by the same
  //   compilation. It should return a JS Array containing 2 elements. The first
  //   should be the bytes for the wasm module in a format supported by
  //   `WebAssembly.compile` or `WebAssembly.compileStreaming`. The second
  //   should be the result of using the JS 'import' API on the js file path.
  async instantiate(additionalImports, {loadDeferredWasm, loadDynamicModule} = {}) {
    let dartInstance;

    // Prints to the console
    function printToConsole(value) {
      if (typeof dartPrint == "function") {
        dartPrint(value);
        return;
      }
      if (typeof console == "object" && typeof console.log != "undefined") {
        console.log(value);
        return;
      }
      if (typeof print == "function") {
        print(value);
        return;
      }

      throw "Unable to print message: " + value;
    }

    // A special symbol attached to functions that wrap Dart functions.
    const jsWrappedDartFunctionSymbol = Symbol("JSWrappedDartFunction");

    function finalizeWrapper(dartFunction, wrapped) {
      wrapped.dartFunction = dartFunction;
      wrapped[jsWrappedDartFunctionSymbol] = true;
      return wrapped;
    }

    // Imports
    const dart2wasm = {
            _4: (o, c) => o instanceof c,
      _6: (o,s,v) => o[s] = v,
      _7: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._7(f,arguments.length,x0) }),
      _8: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._8(f,arguments.length,x0,x1) }),
      _37: x0 => new Array(x0),
      _39: x0 => x0.length,
      _41: (x0,x1) => x0[x1],
      _42: (x0,x1,x2) => { x0[x1] = x2 },
      _43: x0 => new Promise(x0),
      _45: (x0,x1,x2) => new DataView(x0,x1,x2),
      _47: x0 => new Int8Array(x0),
      _48: (x0,x1,x2) => new Uint8Array(x0,x1,x2),
      _49: x0 => new Uint8Array(x0),
      _51: x0 => new Uint8ClampedArray(x0),
      _53: x0 => new Int16Array(x0),
      _55: x0 => new Uint16Array(x0),
      _57: x0 => new Int32Array(x0),
      _59: x0 => new Uint32Array(x0),
      _61: x0 => new Float32Array(x0),
      _63: x0 => new Float64Array(x0),
      _65: (x0,x1,x2) => x0.call(x1,x2),
      _69: () => Symbol("jsBoxedDartObjectProperty"),
      _70: (decoder, codeUnits) => decoder.decode(codeUnits),
      _71: () => new TextDecoder("utf-8", {fatal: true}),
      _72: () => new TextDecoder("utf-8", {fatal: false}),
      _73: (s) => +s,
      _74: x0 => new Uint8Array(x0),
      _75: (x0,x1,x2) => x0.set(x1,x2),
      _76: (x0,x1) => x0.transferFromImageBitmap(x1),
      _78: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._78(f,arguments.length,x0) }),
      _79: x0 => new window.FinalizationRegistry(x0),
      _80: (x0,x1,x2,x3) => x0.register(x1,x2,x3),
      _81: (x0,x1) => x0.unregister(x1),
      _82: (x0,x1,x2) => x0.slice(x1,x2),
      _83: (x0,x1) => x0.decode(x1),
      _84: (x0,x1) => x0.segment(x1),
      _85: () => new TextDecoder(),
      _87: x0 => x0.click(),
      _88: x0 => x0.buffer,
      _89: x0 => x0.wasmMemory,
      _90: () => globalThis.window._flutter_skwasmInstance,
      _91: x0 => x0.rasterStartMilliseconds,
      _92: x0 => x0.rasterEndMilliseconds,
      _93: x0 => x0.imageBitmaps,
      _120: x0 => x0.remove(),
      _121: (x0,x1) => x0.append(x1),
      _122: (x0,x1,x2) => x0.insertBefore(x1,x2),
      _123: (x0,x1) => x0.querySelector(x1),
      _125: (x0,x1) => x0.removeChild(x1),
      _203: x0 => x0.stopPropagation(),
      _204: x0 => x0.preventDefault(),
      _206: (x0,x1,x2,x3) => x0.addEventListener(x1,x2,x3),
      _251: x0 => x0.unlock(),
      _252: x0 => x0.getReader(),
      _253: (x0,x1,x2) => x0.addEventListener(x1,x2),
      _254: (x0,x1,x2) => x0.removeEventListener(x1,x2),
      _255: (x0,x1) => x0.item(x1),
      _256: x0 => x0.next(),
      _257: x0 => x0.now(),
      _258: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._258(f,arguments.length,x0) }),
      _259: (x0,x1) => x0.addListener(x1),
      _260: (x0,x1) => x0.removeListener(x1),
      _261: (x0,x1) => x0.matchMedia(x1),
      _268: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._268(f,arguments.length,x0) }),
      _269: (x0,x1) => x0.getModifierState(x1),
      _270: (x0,x1) => x0.removeProperty(x1),
      _271: (x0,x1) => x0.prepend(x1),
      _272: x0 => x0.disconnect(),
      _273: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._273(f,arguments.length,x0) }),
      _274: (x0,x1) => x0.getAttribute(x1),
      _275: (x0,x1) => x0.contains(x1),
      _276: x0 => x0.blur(),
      _277: x0 => x0.hasFocus(),
      _278: (x0,x1) => x0.hasAttribute(x1),
      _279: (x0,x1) => x0.getModifierState(x1),
      _280: (x0,x1) => x0.appendChild(x1),
      _281: (x0,x1) => x0.createTextNode(x1),
      _282: (x0,x1) => x0.removeAttribute(x1),
      _283: x0 => x0.getBoundingClientRect(),
      _284: (x0,x1) => x0.observe(x1),
      _285: x0 => x0.disconnect(),
      _286: (x0,x1) => x0.closest(x1),
      _696: () => globalThis.window.flutterConfiguration,
      _697: x0 => x0.assetBase,
      _703: x0 => x0.debugShowSemanticsNodes,
      _704: x0 => x0.hostElement,
      _705: x0 => x0.multiViewEnabled,
      _706: x0 => x0.nonce,
      _708: x0 => x0.fontFallbackBaseUrl,
      _712: x0 => x0.console,
      _713: x0 => x0.devicePixelRatio,
      _714: x0 => x0.document,
      _715: x0 => x0.history,
      _716: x0 => x0.innerHeight,
      _717: x0 => x0.innerWidth,
      _718: x0 => x0.location,
      _719: x0 => x0.navigator,
      _720: x0 => x0.visualViewport,
      _721: x0 => x0.performance,
      _725: (x0,x1) => x0.getComputedStyle(x1),
      _726: x0 => x0.screen,
      _727: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._727(f,arguments.length,x0) }),
      _728: (x0,x1) => x0.requestAnimationFrame(x1),
      _733: (x0,x1) => x0.warn(x1),
      _736: x0 => globalThis.parseFloat(x0),
      _737: () => globalThis.window,
      _738: () => globalThis.Intl,
      _739: () => globalThis.Symbol,
      _742: x0 => x0.clipboard,
      _743: x0 => x0.maxTouchPoints,
      _744: x0 => x0.vendor,
      _745: x0 => x0.language,
      _746: x0 => x0.platform,
      _747: x0 => x0.userAgent,
      _748: (x0,x1) => x0.vibrate(x1),
      _749: x0 => x0.languages,
      _750: x0 => x0.documentElement,
      _751: (x0,x1) => x0.querySelector(x1),
      _754: (x0,x1) => x0.createElement(x1),
      _757: (x0,x1) => x0.createEvent(x1),
      _758: x0 => x0.activeElement,
      _761: x0 => x0.head,
      _762: x0 => x0.body,
      _764: (x0,x1) => { x0.title = x1 },
      _767: x0 => x0.visibilityState,
      _768: () => globalThis.document,
      _769: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._769(f,arguments.length,x0) }),
      _770: (x0,x1) => x0.dispatchEvent(x1),
      _778: x0 => x0.target,
      _780: x0 => x0.timeStamp,
      _781: x0 => x0.type,
      _783: (x0,x1,x2,x3) => x0.initEvent(x1,x2,x3),
      _790: x0 => x0.firstChild,
      _794: x0 => x0.parentElement,
      _796: (x0,x1) => { x0.textContent = x1 },
      _797: x0 => x0.parentNode,
      _799: x0 => x0.isConnected,
      _803: x0 => x0.firstElementChild,
      _805: x0 => x0.nextElementSibling,
      _806: x0 => x0.clientHeight,
      _807: x0 => x0.clientWidth,
      _808: x0 => x0.offsetHeight,
      _809: x0 => x0.offsetWidth,
      _810: x0 => x0.id,
      _811: (x0,x1) => { x0.id = x1 },
      _814: (x0,x1) => { x0.spellcheck = x1 },
      _815: x0 => x0.tagName,
      _816: x0 => x0.style,
      _818: (x0,x1) => x0.querySelectorAll(x1),
      _819: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _820: x0 => x0.tabIndex,
      _821: (x0,x1) => { x0.tabIndex = x1 },
      _822: (x0,x1) => x0.focus(x1),
      _823: x0 => x0.scrollTop,
      _824: (x0,x1) => { x0.scrollTop = x1 },
      _825: x0 => x0.scrollLeft,
      _826: (x0,x1) => { x0.scrollLeft = x1 },
      _827: x0 => x0.classList,
      _829: (x0,x1) => { x0.className = x1 },
      _831: (x0,x1) => x0.getElementsByClassName(x1),
      _832: (x0,x1) => x0.attachShadow(x1),
      _835: x0 => x0.computedStyleMap(),
      _836: (x0,x1) => x0.get(x1),
      _842: (x0,x1) => x0.getPropertyValue(x1),
      _843: (x0,x1,x2,x3) => x0.setProperty(x1,x2,x3),
      _844: x0 => x0.offsetLeft,
      _845: x0 => x0.offsetTop,
      _846: x0 => x0.offsetParent,
      _848: (x0,x1) => { x0.name = x1 },
      _849: x0 => x0.content,
      _850: (x0,x1) => { x0.content = x1 },
      _868: (x0,x1) => { x0.nonce = x1 },
      _873: (x0,x1) => { x0.width = x1 },
      _875: (x0,x1) => { x0.height = x1 },
      _878: (x0,x1) => x0.getContext(x1),
      _940: (x0,x1) => x0.fetch(x1),
      _941: x0 => x0.status,
      _943: x0 => x0.body,
      _944: x0 => x0.arrayBuffer(),
      _947: x0 => x0.read(),
      _948: x0 => x0.value,
      _949: x0 => x0.done,
      _952: x0 => x0.x,
      _953: x0 => x0.y,
      _956: x0 => x0.top,
      _957: x0 => x0.right,
      _958: x0 => x0.bottom,
      _959: x0 => x0.left,
      _971: x0 => x0.height,
      _972: x0 => x0.width,
      _973: x0 => x0.scale,
      _974: (x0,x1) => { x0.value = x1 },
      _977: (x0,x1) => { x0.placeholder = x1 },
      _979: (x0,x1) => { x0.name = x1 },
      _980: x0 => x0.selectionDirection,
      _981: x0 => x0.selectionStart,
      _982: x0 => x0.selectionEnd,
      _985: x0 => x0.value,
      _987: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _988: x0 => x0.readText(),
      _989: (x0,x1) => x0.writeText(x1),
      _991: x0 => x0.altKey,
      _992: x0 => x0.code,
      _993: x0 => x0.ctrlKey,
      _994: x0 => x0.key,
      _995: x0 => x0.keyCode,
      _996: x0 => x0.location,
      _997: x0 => x0.metaKey,
      _998: x0 => x0.repeat,
      _999: x0 => x0.shiftKey,
      _1000: x0 => x0.isComposing,
      _1002: x0 => x0.state,
      _1003: (x0,x1) => x0.go(x1),
      _1005: (x0,x1,x2,x3) => x0.pushState(x1,x2,x3),
      _1006: (x0,x1,x2,x3) => x0.replaceState(x1,x2,x3),
      _1007: x0 => x0.pathname,
      _1008: x0 => x0.search,
      _1009: x0 => x0.hash,
      _1013: x0 => x0.state,
      _1020: x0 => new MutationObserver(x0),
      _1021: (x0,x1,x2) => x0.observe(x1,x2),
      _1022: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1022(f,arguments.length,x0,x1) }),
      _1025: x0 => x0.attributeName,
      _1026: x0 => x0.type,
      _1027: x0 => x0.matches,
      _1028: x0 => x0.matches,
      _1032: x0 => x0.relatedTarget,
      _1034: x0 => x0.clientX,
      _1035: x0 => x0.clientY,
      _1036: x0 => x0.offsetX,
      _1037: x0 => x0.offsetY,
      _1040: x0 => x0.button,
      _1041: x0 => x0.buttons,
      _1042: x0 => x0.ctrlKey,
      _1046: x0 => x0.pointerId,
      _1047: x0 => x0.pointerType,
      _1048: x0 => x0.pressure,
      _1049: x0 => x0.tiltX,
      _1050: x0 => x0.tiltY,
      _1051: x0 => x0.getCoalescedEvents(),
      _1054: x0 => x0.deltaX,
      _1055: x0 => x0.deltaY,
      _1056: x0 => x0.wheelDeltaX,
      _1057: x0 => x0.wheelDeltaY,
      _1058: x0 => x0.deltaMode,
      _1065: x0 => x0.changedTouches,
      _1068: x0 => x0.clientX,
      _1069: x0 => x0.clientY,
      _1072: x0 => x0.data,
      _1075: (x0,x1) => { x0.disabled = x1 },
      _1077: (x0,x1) => { x0.type = x1 },
      _1078: (x0,x1) => { x0.max = x1 },
      _1079: (x0,x1) => { x0.min = x1 },
      _1080: x0 => x0.value,
      _1081: (x0,x1) => { x0.value = x1 },
      _1082: x0 => x0.disabled,
      _1083: (x0,x1) => { x0.disabled = x1 },
      _1085: (x0,x1) => { x0.placeholder = x1 },
      _1087: (x0,x1) => { x0.name = x1 },
      _1089: (x0,x1) => { x0.autocomplete = x1 },
      _1090: x0 => x0.selectionDirection,
      _1092: x0 => x0.selectionStart,
      _1093: x0 => x0.selectionEnd,
      _1096: (x0,x1,x2) => x0.setSelectionRange(x1,x2),
      _1097: (x0,x1) => x0.add(x1),
      _1100: (x0,x1) => { x0.noValidate = x1 },
      _1101: (x0,x1) => { x0.method = x1 },
      _1102: (x0,x1) => { x0.action = x1 },
      _1128: x0 => x0.orientation,
      _1129: x0 => x0.width,
      _1130: x0 => x0.height,
      _1131: (x0,x1) => x0.lock(x1),
      _1150: x0 => new ResizeObserver(x0),
      _1153: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1153(f,arguments.length,x0,x1) }),
      _1161: x0 => x0.length,
      _1162: x0 => x0.iterator,
      _1163: x0 => x0.Segmenter,
      _1164: x0 => x0.v8BreakIterator,
      _1165: (x0,x1) => new Intl.Segmenter(x0,x1),
      _1166: x0 => x0.done,
      _1167: x0 => x0.value,
      _1168: x0 => x0.index,
      _1172: (x0,x1) => new Intl.v8BreakIterator(x0,x1),
      _1173: (x0,x1) => x0.adoptText(x1),
      _1174: x0 => x0.first(),
      _1175: x0 => x0.next(),
      _1176: x0 => x0.current(),
      _1182: x0 => x0.hostElement,
      _1183: x0 => x0.viewConstraints,
      _1186: x0 => x0.maxHeight,
      _1187: x0 => x0.maxWidth,
      _1188: x0 => x0.minHeight,
      _1189: x0 => x0.minWidth,
      _1190: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1190(f,arguments.length,x0) }),
      _1191: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1191(f,arguments.length,x0) }),
      _1192: (x0,x1) => ({addView: x0,removeView: x1}),
      _1193: x0 => x0.loader,
      _1194: () => globalThis._flutter,
      _1195: (x0,x1) => x0.didCreateEngineInitializer(x1),
      _1196: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1196(f,arguments.length,x0) }),
      _1197: f => finalizeWrapper(f, function() { return dartInstance.exports._1197(f,arguments.length) }),
      _1198: (x0,x1) => ({initializeEngine: x0,autoStart: x1}),
      _1199: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1199(f,arguments.length,x0) }),
      _1200: x0 => ({runApp: x0}),
      _1201: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1201(f,arguments.length,x0,x1) }),
      _1202: x0 => x0.length,
      _1287: (x0,x1) => x0.createElement(x1),
      _1288: (x0,x1,x2) => x0.setAttribute(x1,x2),
      _1290: (x0,x1) => x0.getAttribute(x1),
      _1298: () => globalThis.AppleID.auth.signIn(),
      _1306: x0 => x0.authorization,
      _1307: x0 => x0.user,
      _1308: x0 => x0.error,
      _1310: x0 => x0.code,
      _1311: x0 => x0.id_token,
      _1312: x0 => x0.state,
      _1313: x0 => x0.email,
      _1314: x0 => x0.name,
      _1315: x0 => x0.firstName,
      _1316: x0 => x0.lastName,
      _1317: x0 => globalThis.firebase_firestore.memoryLocalCache(x0),
      _1318: x0 => ({cacheSizeBytes: x0}),
      _1319: x0 => globalThis.firebase_firestore.persistentLocalCache(x0),
      _1321: (x0,x1,x2,x3) => ({ignoreUndefinedProperties: x0,experimentalForceLongPolling: x1,experimentalAutoDetectLongPolling: x2,localCache: x3}),
      _1323: x0 => x0.toArray(),
      _1324: x0 => x0.toUint8Array(),
      _1325: x0 => ({serverTimestamps: x0}),
      _1326: x0 => ({source: x0}),
      _1327: x0 => ({merge: x0}),
      _1329: x0 => new firebase_firestore.FieldPath(x0),
      _1330: (x0,x1) => new firebase_firestore.FieldPath(x0,x1),
      _1331: (x0,x1,x2) => new firebase_firestore.FieldPath(x0,x1,x2),
      _1332: (x0,x1,x2,x3) => new firebase_firestore.FieldPath(x0,x1,x2,x3),
      _1333: (x0,x1,x2,x3,x4) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4),
      _1334: (x0,x1,x2,x3,x4,x5) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5),
      _1335: (x0,x1,x2,x3,x4,x5,x6) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6),
      _1336: (x0,x1,x2,x3,x4,x5,x6,x7) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7),
      _1337: (x0,x1,x2,x3,x4,x5,x6,x7,x8) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8),
      _1338: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9) => new firebase_firestore.FieldPath(x0,x1,x2,x3,x4,x5,x6,x7,x8,x9),
      _1339: () => globalThis.firebase_firestore.documentId(),
      _1340: (x0,x1) => new firebase_firestore.GeoPoint(x0,x1),
      _1341: x0 => globalThis.firebase_firestore.vector(x0),
      _1342: x0 => globalThis.firebase_firestore.Bytes.fromUint8Array(x0),
      _1344: (x0,x1) => globalThis.firebase_firestore.collection(x0,x1),
      _1346: (x0,x1) => globalThis.firebase_firestore.doc(x0,x1),
      _1349: x0 => x0.call(),
      _1351: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1351(f,arguments.length,x0) }),
      _1352: x0 => ({maxAttempts: x0}),
      _1353: (x0,x1,x2) => globalThis.firebase_firestore.runTransaction(x0,x1,x2),
      _1379: x0 => globalThis.firebase_firestore.getDoc(x0),
      _1380: x0 => globalThis.firebase_firestore.getDocFromServer(x0),
      _1381: x0 => globalThis.firebase_firestore.getDocFromCache(x0),
      _1382: (x0,x1) => ({includeMetadataChanges: x0,source: x1}),
      _1383: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1383(f,arguments.length,x0) }),
      _1384: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1384(f,arguments.length,x0) }),
      _1385: (x0,x1,x2,x3) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2,x3),
      _1386: (x0,x1,x2) => globalThis.firebase_firestore.onSnapshot(x0,x1,x2),
      _1387: (x0,x1,x2) => globalThis.firebase_firestore.setDoc(x0,x1,x2),
      _1388: (x0,x1) => globalThis.firebase_firestore.setDoc(x0,x1),
      _1389: (x0,x1) => globalThis.firebase_firestore.query(x0,x1),
      _1390: x0 => globalThis.firebase_firestore.getDocs(x0),
      _1391: x0 => globalThis.firebase_firestore.getDocsFromServer(x0),
      _1392: x0 => globalThis.firebase_firestore.getDocsFromCache(x0),
      _1393: x0 => globalThis.firebase_firestore.limit(x0),
      _1394: x0 => globalThis.firebase_firestore.limitToLast(x0),
      _1395: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1395(f,arguments.length,x0) }),
      _1396: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1396(f,arguments.length,x0) }),
      _1397: (x0,x1) => globalThis.firebase_firestore.orderBy(x0,x1),
      _1399: (x0,x1,x2) => globalThis.firebase_firestore.where(x0,x1,x2),
      _1405: (x0,x1) => x0.data(x1),
      _1409: x0 => x0.docChanges(),
      _1414: (x0,x1,x2,x3) => x0.set(x1,x2,x3),
      _1415: (x0,x1,x2) => x0.set(x1,x2),
      _1417: () => globalThis.firebase_firestore.deleteField(),
      _1418: () => globalThis.firebase_firestore.serverTimestamp(),
      _1425: (x0,x1,x2) => globalThis.firebase_firestore.initializeFirestore(x0,x1,x2),
      _1426: (x0,x1) => globalThis.firebase_firestore.getFirestore(x0,x1),
      _1428: x0 => globalThis.firebase_firestore.Timestamp.fromMillis(x0),
      _1429: f => finalizeWrapper(f, function() { return dartInstance.exports._1429(f,arguments.length) }),
      _1446: () => globalThis.firebase_firestore.updateDoc,
      _1447: () => globalThis.firebase_firestore.or,
      _1448: () => globalThis.firebase_firestore.and,
      _1453: x0 => x0.path,
      _1456: () => globalThis.firebase_firestore.GeoPoint,
      _1457: x0 => x0.latitude,
      _1458: x0 => x0.longitude,
      _1460: () => globalThis.firebase_firestore.VectorValue,
      _1461: () => globalThis.firebase_firestore.Bytes,
      _1464: x0 => x0.type,
      _1466: x0 => x0.doc,
      _1468: x0 => x0.oldIndex,
      _1470: x0 => x0.newIndex,
      _1472: () => globalThis.firebase_firestore.DocumentReference,
      _1476: x0 => x0.path,
      _1485: x0 => x0.metadata,
      _1486: x0 => x0.ref,
      _1491: x0 => x0.docs,
      _1493: x0 => x0.metadata,
      _1497: () => globalThis.firebase_firestore.Timestamp,
      _1498: x0 => x0.seconds,
      _1499: x0 => x0.nanoseconds,
      _1535: x0 => x0.hasPendingWrites,
      _1537: x0 => x0.fromCache,
      _1544: x0 => x0.source,
      _1549: () => globalThis.firebase_firestore.startAfter,
      _1550: () => globalThis.firebase_firestore.startAt,
      _1551: () => globalThis.firebase_firestore.endBefore,
      _1552: () => globalThis.firebase_firestore.endAt,
      _1565: (x0,x1) => x0.item(x1),
      _1566: (x0,x1) => x0.querySelector(x1),
      _1567: (x0,x1) => ({timeout: x0,limitedUseAppCheckTokens: x1}),
      _1589: x0 => x0.reload(),
      _1590: (x0,x1) => globalThis.firebase_auth.sendEmailVerification(x0,x1),
      _1596: (x0,x1) => globalThis.firebase_auth.updateProfile(x0,x1),
      _1599: x0 => x0.toJSON(),
      _1600: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1600(f,arguments.length,x0) }),
      _1601: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1601(f,arguments.length,x0) }),
      _1602: (x0,x1,x2) => x0.onAuthStateChanged(x1,x2),
      _1603: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1603(f,arguments.length,x0) }),
      _1604: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1604(f,arguments.length,x0) }),
      _1605: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1605(f,arguments.length,x0) }),
      _1606: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1606(f,arguments.length,x0) }),
      _1607: (x0,x1,x2) => x0.onIdTokenChanged(x1,x2),
      _1611: (x0,x1,x2) => globalThis.firebase_auth.createUserWithEmailAndPassword(x0,x1,x2),
      _1618: (x0,x1) => globalThis.firebase_auth.signInWithCredential(x0,x1),
      _1621: (x0,x1,x2) => globalThis.firebase_auth.signInWithEmailAndPassword(x0,x1,x2),
      _1626: x0 => x0.signOut(),
      _1627: (x0,x1) => globalThis.firebase_auth.connectAuthEmulator(x0,x1),
      _1645: (x0,x1) => globalThis.firebase_auth.GoogleAuthProvider.credential(x0,x1),
      _1646: x0 => new firebase_auth.OAuthProvider(x0),
      _1649: (x0,x1) => x0.credential(x1),
      _1650: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromResult(x0),
      _1665: x0 => globalThis.firebase_auth.getAdditionalUserInfo(x0),
      _1666: (x0,x1,x2) => ({errorMap: x0,persistence: x1,popupRedirectResolver: x2}),
      _1667: (x0,x1) => globalThis.firebase_auth.initializeAuth(x0,x1),
      _1668: (x0,x1,x2) => ({accessToken: x0,idToken: x1,rawNonce: x2}),
      _1673: x0 => globalThis.firebase_auth.OAuthProvider.credentialFromError(x0),
      _1676: (x0,x1) => ({displayName: x0,photoURL: x1}),
      _1678: x0 => ({bundleId: x0}),
      _1679: (x0,x1,x2) => ({packageName: x0,minimumVersion: x1,installApp: x2}),
      _1688: () => globalThis.firebase_auth.debugErrorMap,
      _1691: () => globalThis.firebase_auth.browserSessionPersistence,
      _1693: () => globalThis.firebase_auth.browserLocalPersistence,
      _1695: () => globalThis.firebase_auth.indexedDBLocalPersistence,
      _1698: x0 => globalThis.firebase_auth.multiFactor(x0),
      _1699: (x0,x1) => globalThis.firebase_auth.getMultiFactorResolver(x0,x1),
      _1701: x0 => x0.currentUser,
      _1703: (x0,x1) => { x0.languageCode = x1 },
      _1705: x0 => x0.tenantId,
      _1715: x0 => x0.displayName,
      _1716: x0 => x0.email,
      _1717: x0 => x0.phoneNumber,
      _1718: x0 => x0.photoURL,
      _1719: x0 => x0.providerId,
      _1720: x0 => x0.uid,
      _1721: x0 => x0.emailVerified,
      _1722: x0 => x0.isAnonymous,
      _1723: x0 => x0.providerData,
      _1724: x0 => x0.refreshToken,
      _1725: x0 => x0.tenantId,
      _1726: x0 => x0.metadata,
      _1728: x0 => x0.providerId,
      _1729: x0 => x0.signInMethod,
      _1730: x0 => x0.accessToken,
      _1731: x0 => x0.idToken,
      _1732: x0 => x0.secret,
      _1743: x0 => x0.creationTime,
      _1744: x0 => x0.lastSignInTime,
      _1749: x0 => x0.code,
      _1751: x0 => x0.message,
      _1763: x0 => x0.email,
      _1764: x0 => x0.phoneNumber,
      _1765: x0 => x0.tenantId,
      _1771: (x0,x1) => { x0.iOS = x1 },
      _1773: (x0,x1) => { x0.android = x1 },
      _1788: x0 => x0.user,
      _1791: x0 => x0.providerId,
      _1792: x0 => x0.profile,
      _1793: x0 => x0.username,
      _1794: x0 => x0.isNewUser,
      _1797: () => globalThis.firebase_auth.browserPopupRedirectResolver,
      _1802: x0 => x0.displayName,
      _1803: x0 => x0.enrollmentTime,
      _1804: x0 => x0.factorId,
      _1805: x0 => x0.uid,
      _1807: x0 => x0.hints,
      _1808: x0 => x0.session,
      _1810: x0 => x0.phoneNumber,
      _1820: x0 => ({displayName: x0}),
      _1821: x0 => ({photoURL: x0}),
      _1822: (x0,x1) => x0.getItem(x1),
      _1828: (x0,x1) => x0.appendChild(x1),
      _1829: (x0,x1) => ({url: x0,handleCodeInApp: x1}),
      _1831: (x0,x1,x2,x3,x4,x5,x6,x7) => ({apiKey: x0,authDomain: x1,databaseURL: x2,projectId: x3,storageBucket: x4,messagingSenderId: x5,measurementId: x6,appId: x7}),
      _1832: (x0,x1) => globalThis.firebase_core.initializeApp(x0,x1),
      _1833: x0 => globalThis.firebase_core.getApp(x0),
      _1834: () => globalThis.firebase_core.getApp(),
      _1836: (x0,x1) => ({next: x0,error: x1}),
      _1838: x0 => globalThis.firebase_messaging.getMessaging(x0),
      _1840: (x0,x1) => globalThis.firebase_messaging.getToken(x0,x1),
      _1842: (x0,x1) => globalThis.firebase_messaging.onMessage(x0,x1),
      _1846: x0 => x0.title,
      _1847: x0 => x0.body,
      _1848: x0 => x0.image,
      _1849: x0 => x0.messageId,
      _1850: x0 => x0.collapseKey,
      _1851: x0 => x0.fcmOptions,
      _1852: x0 => x0.notification,
      _1853: x0 => x0.data,
      _1854: x0 => x0.from,
      _1855: x0 => x0.analyticsLabel,
      _1856: x0 => x0.link,
      _1857: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1857(f,arguments.length,x0) }),
      _1858: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1858(f,arguments.length,x0) }),
      _1860: () => globalThis.firebase_core.SDK_VERSION,
      _1866: x0 => x0.apiKey,
      _1868: x0 => x0.authDomain,
      _1870: x0 => x0.databaseURL,
      _1872: x0 => x0.projectId,
      _1874: x0 => x0.storageBucket,
      _1876: x0 => x0.messagingSenderId,
      _1878: x0 => x0.measurementId,
      _1880: x0 => x0.appId,
      _1882: x0 => x0.name,
      _1883: x0 => x0.options,
      _1884: (x0,x1) => globalThis.firebase_functions.getFunctions(x0,x1),
      _1886: (x0,x1,x2) => globalThis.firebase_functions.httpsCallable(x0,x1,x2),
      _1895: x0 => x0.data,
      _1907: (x0,x1) => globalThis.firebase_functions.httpsCallable(x0,x1),
      _1909: (x0,x1) => x0.debug(x1),
      _1910: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1910(f,arguments.length,x0) }),
      _1911: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1911(f,arguments.length,x0,x1) }),
      _1912: (x0,x1) => ({createScript: x0,createScriptURL: x1}),
      _1913: (x0,x1,x2) => x0.createPolicy(x1,x2),
      _1914: (x0,x1) => x0.createScriptURL(x1),
      _1915: (x0,x1,x2) => x0.createScript(x1,x2),
      _1916: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._1916(f,arguments.length,x0) }),
      _1918: (x0,x1) => x0.initialize(x1),
      _1922: x0 => x0.disableAutoSelect(),
      _1923: f => finalizeWrapper(f, function(x0,x1) { return dartInstance.exports._1923(f,arguments.length,x0,x1) }),
      _1927: Date.now,
      _1929: s => new Date(s * 1000).getTimezoneOffset() * 60,
      _1930: s => {
        if (!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(s)) {
          return NaN;
        }
        return parseFloat(s);
      },
      _1931: () => {
        let stackString = new Error().stack.toString();
        let frames = stackString.split('\n');
        let drop = 2;
        if (frames[0] === 'Error') {
            drop += 1;
        }
        return frames.slice(drop).join('\n');
      },
      _1932: () => typeof dartUseDateNowForTicks !== "undefined",
      _1933: () => 1000 * performance.now(),
      _1934: () => Date.now(),
      _1937: () => new WeakMap(),
      _1938: (map, o) => map.get(o),
      _1939: (map, o, v) => map.set(o, v),
      _1940: x0 => new WeakRef(x0),
      _1941: x0 => x0.deref(),
      _1948: () => globalThis.WeakRef,
      _1951: s => JSON.stringify(s),
      _1952: s => printToConsole(s),
      _1953: (o, p, r) => o.replaceAll(p, () => r),
      _1954: (o, p, r) => o.replace(p, () => r),
      _1955: Function.prototype.call.bind(String.prototype.toLowerCase),
      _1956: s => s.toUpperCase(),
      _1957: s => s.trim(),
      _1958: s => s.trimLeft(),
      _1959: s => s.trimRight(),
      _1960: (string, times) => string.repeat(times),
      _1961: Function.prototype.call.bind(String.prototype.indexOf),
      _1962: (s, p, i) => s.lastIndexOf(p, i),
      _1963: (string, token) => string.split(token),
      _1964: Object.is,
      _1965: o => o instanceof Array,
      _1966: (a, i) => a.push(i),
      _1970: a => a.pop(),
      _1971: (a, i) => a.splice(i, 1),
      _1972: (a, s) => a.join(s),
      _1973: (a, s, e) => a.slice(s, e),
      _1976: a => a.length,
      _1978: (a, i) => a[i],
      _1979: (a, i, v) => a[i] = v,
      _1981: o => {
        if (o instanceof ArrayBuffer) return 0;
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
          return 1;
        }
        return 2;
      },
      _1982: (o, offsetInBytes, lengthInBytes) => {
        var dst = new ArrayBuffer(lengthInBytes);
        new Uint8Array(dst).set(new Uint8Array(o, offsetInBytes, lengthInBytes));
        return new DataView(dst);
      },
      _1984: o => o instanceof Uint8Array,
      _1985: (o, start, length) => new Uint8Array(o.buffer, o.byteOffset + start, length),
      _1986: o => o instanceof Int8Array,
      _1987: (o, start, length) => new Int8Array(o.buffer, o.byteOffset + start, length),
      _1988: o => o instanceof Uint8ClampedArray,
      _1989: (o, start, length) => new Uint8ClampedArray(o.buffer, o.byteOffset + start, length),
      _1990: o => o instanceof Uint16Array,
      _1991: (o, start, length) => new Uint16Array(o.buffer, o.byteOffset + start, length),
      _1992: o => o instanceof Int16Array,
      _1993: (o, start, length) => new Int16Array(o.buffer, o.byteOffset + start, length),
      _1994: o => o instanceof Uint32Array,
      _1995: (o, start, length) => new Uint32Array(o.buffer, o.byteOffset + start, length),
      _1996: o => o instanceof Int32Array,
      _1997: (o, start, length) => new Int32Array(o.buffer, o.byteOffset + start, length),
      _1999: (o, start, length) => new BigInt64Array(o.buffer, o.byteOffset + start, length),
      _2000: o => o instanceof Float32Array,
      _2001: (o, start, length) => new Float32Array(o.buffer, o.byteOffset + start, length),
      _2002: o => o instanceof Float64Array,
      _2003: (o, start, length) => new Float64Array(o.buffer, o.byteOffset + start, length),
      _2004: (t, s) => t.set(s),
      _2006: (o) => new DataView(o.buffer, o.byteOffset, o.byteLength),
      _2008: o => o.buffer,
      _2009: o => o.byteOffset,
      _2010: Function.prototype.call.bind(Object.getOwnPropertyDescriptor(DataView.prototype, 'byteLength').get),
      _2011: (b, o) => new DataView(b, o),
      _2012: (b, o, l) => new DataView(b, o, l),
      _2013: Function.prototype.call.bind(DataView.prototype.getUint8),
      _2014: Function.prototype.call.bind(DataView.prototype.setUint8),
      _2015: Function.prototype.call.bind(DataView.prototype.getInt8),
      _2016: Function.prototype.call.bind(DataView.prototype.setInt8),
      _2017: Function.prototype.call.bind(DataView.prototype.getUint16),
      _2018: Function.prototype.call.bind(DataView.prototype.setUint16),
      _2019: Function.prototype.call.bind(DataView.prototype.getInt16),
      _2020: Function.prototype.call.bind(DataView.prototype.setInt16),
      _2021: Function.prototype.call.bind(DataView.prototype.getUint32),
      _2022: Function.prototype.call.bind(DataView.prototype.setUint32),
      _2023: Function.prototype.call.bind(DataView.prototype.getInt32),
      _2024: Function.prototype.call.bind(DataView.prototype.setInt32),
      _2027: Function.prototype.call.bind(DataView.prototype.getBigInt64),
      _2028: Function.prototype.call.bind(DataView.prototype.setBigInt64),
      _2029: Function.prototype.call.bind(DataView.prototype.getFloat32),
      _2030: Function.prototype.call.bind(DataView.prototype.setFloat32),
      _2031: Function.prototype.call.bind(DataView.prototype.getFloat64),
      _2032: Function.prototype.call.bind(DataView.prototype.setFloat64),
      _2045: (ms, c) =>
      setTimeout(() => dartInstance.exports.$invokeCallback(c),ms),
      _2046: (handle) => clearTimeout(handle),
      _2047: (ms, c) =>
      setInterval(() => dartInstance.exports.$invokeCallback(c), ms),
      _2048: (handle) => clearInterval(handle),
      _2049: (c) =>
      queueMicrotask(() => dartInstance.exports.$invokeCallback(c)),
      _2050: () => Date.now(),
      _2055: o => Object.keys(o),
      _2079: x0 => x0.trustedTypes,
      _2080: (x0,x1) => { x0.src = x1 },
      _2081: (x0,x1) => x0.createScriptURL(x1),
      _2082: x0 => x0.nonce,
      _2083: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2083(f,arguments.length,x0) }),
      _2084: x0 => ({createScriptURL: x0}),
      _2085: (x0,x1) => x0.querySelectorAll(x1),
      _2086: x0 => x0.trustedTypes,
      _2087: (x0,x1) => { x0.text = x1 },
      _2098: (s, m) => {
        try {
          return new RegExp(s, m);
        } catch (e) {
          return String(e);
        }
      },
      _2099: (x0,x1) => x0.exec(x1),
      _2100: (x0,x1) => x0.test(x1),
      _2101: x0 => x0.pop(),
      _2103: o => o === undefined,
      _2105: o => typeof o === 'function' && o[jsWrappedDartFunctionSymbol] === true,
      _2107: o => {
        const proto = Object.getPrototypeOf(o);
        return proto === Object.prototype || proto === null;
      },
      _2108: o => o instanceof RegExp,
      _2109: (l, r) => l === r,
      _2110: o => o,
      _2111: o => o,
      _2112: o => o,
      _2113: b => !!b,
      _2114: o => o.length,
      _2116: (o, i) => o[i],
      _2117: f => f.dartFunction,
      _2118: () => ({}),
      _2119: () => [],
      _2121: () => globalThis,
      _2122: (constructor, args) => {
        const factoryFunction = constructor.bind.apply(
            constructor, [null, ...args]);
        return new factoryFunction();
      },
      _2123: (o, p) => p in o,
      _2124: (o, p) => o[p],
      _2125: (o, p, v) => o[p] = v,
      _2126: (o, m, a) => o[m].apply(o, a),
      _2128: o => String(o),
      _2129: (p, s, f) => p.then(s, (e) => f(e, e === undefined)),
      _2130: o => {
        if (o === undefined) return 1;
        var type = typeof o;
        if (type === 'boolean') return 2;
        if (type === 'number') return 3;
        if (type === 'string') return 4;
        if (o instanceof Array) return 5;
        if (ArrayBuffer.isView(o)) {
          if (o instanceof Int8Array) return 6;
          if (o instanceof Uint8Array) return 7;
          if (o instanceof Uint8ClampedArray) return 8;
          if (o instanceof Int16Array) return 9;
          if (o instanceof Uint16Array) return 10;
          if (o instanceof Int32Array) return 11;
          if (o instanceof Uint32Array) return 12;
          if (o instanceof Float32Array) return 13;
          if (o instanceof Float64Array) return 14;
          if (o instanceof DataView) return 15;
        }
        if (o instanceof ArrayBuffer) return 16;
        // Feature check for `SharedArrayBuffer` before doing a type-check.
        if (globalThis.SharedArrayBuffer !== undefined &&
            o instanceof SharedArrayBuffer) {
            return 17;
        }
        return 18;
      },
      _2131: o => [o],
      _2132: (o0, o1) => [o0, o1],
      _2133: (o0, o1, o2) => [o0, o1, o2],
      _2134: (o0, o1, o2, o3) => [o0, o1, o2, o3],
      _2135: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI8ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2136: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI8ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2139: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmI32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2140: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmI32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2141: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF32ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2142: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF32ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2143: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const getValue = dartInstance.exports.$wasmF64ArrayGet;
        for (let i = 0; i < length; i++) {
          jsArray[jsArrayOffset + i] = getValue(wasmArray, wasmArrayOffset + i);
        }
      },
      _2144: (jsArray, jsArrayOffset, wasmArray, wasmArrayOffset, length) => {
        const setValue = dartInstance.exports.$wasmF64ArraySet;
        for (let i = 0; i < length; i++) {
          setValue(wasmArray, wasmArrayOffset + i, jsArray[jsArrayOffset + i]);
        }
      },
      _2145: x0 => new ArrayBuffer(x0),
      _2146: s => {
        if (/[[\]{}()*+?.\\^$|]/.test(s)) {
            s = s.replace(/[[\]{}()*+?.\\^$|]/g, '\\$&');
        }
        return s;
      },
      _2148: x0 => x0.index,
      _2149: x0 => x0.groups,
      _2150: x0 => x0.flags,
      _2151: x0 => x0.multiline,
      _2152: x0 => x0.ignoreCase,
      _2153: x0 => x0.unicode,
      _2154: x0 => x0.dotAll,
      _2155: (x0,x1) => { x0.lastIndex = x1 },
      _2156: (o, p) => p in o,
      _2157: (o, p) => o[p],
      _2158: (o, p, v) => o[p] = v,
      _2159: (o, p) => delete o[p],
      _2160: x0 => x0.random(),
      _2163: () => globalThis.Math,
      _2164: Function.prototype.call.bind(Number.prototype.toString),
      _2165: Function.prototype.call.bind(BigInt.prototype.toString),
      _2166: Function.prototype.call.bind(Number.prototype.toString),
      _2167: (d, digits) => d.toFixed(digits),
      _2259: () => globalThis.google.accounts.id,
      _2273: f => finalizeWrapper(f, function(x0) { return dartInstance.exports._2273(f,arguments.length,x0) }),
      _2276: (x0,x1,x2,x3,x4,x5,x6,x7,x8,x9,x10,x11,x12,x13,x14,x15,x16) => ({client_id: x0,auto_select: x1,callback: x2,login_uri: x3,native_callback: x4,cancel_on_tap_outside: x5,prompt_parent_id: x6,nonce: x7,context: x8,state_cookie_domain: x9,ux_mode: x10,allowed_parent_origin: x11,intermediate_iframe_close_callback: x12,itp_support: x13,login_hint: x14,hd: x15,use_fedcm_for_prompt: x16}),
      _2287: x0 => x0.error,
      _2289: x0 => x0.credential,
      _2300: x0 => { globalThis.onGoogleLibraryLoad = x0 },
      _2301: f => finalizeWrapper(f, function() { return dartInstance.exports._2301(f,arguments.length) }),
      _2627: (x0,x1) => { x0.nonce = x1 },
      _3665: (x0,x1) => { x0.src = x1 },
      _3667: (x0,x1) => { x0.type = x1 },
      _3671: (x0,x1) => { x0.async = x1 },
      _3673: (x0,x1) => { x0.defer = x1 },
      _3675: (x0,x1) => { x0.crossOrigin = x1 },
      _3677: (x0,x1) => { x0.text = x1 },
      _4134: () => globalThis.window,
      _4174: x0 => x0.document,
      _4177: x0 => x0.location,
      _4196: x0 => x0.navigator,
      _4458: x0 => x0.trustedTypes,
      _4459: x0 => x0.sessionStorage,
      _4475: x0 => x0.hostname,
      _4585: x0 => x0.userAgent,
      _6746: x0 => x0.length,
      _6807: () => globalThis.document,
      _6889: x0 => x0.head,
      _7220: (x0,x1) => { x0.id = x1 },
      _13620: () => globalThis.console,
      _13647: x0 => x0.name,
      _13648: x0 => x0.message,
      _13649: x0 => x0.code,
      _13651: x0 => x0.customData,

    };

    const baseImports = {
      dart2wasm: dart2wasm,
      Math: Math,
      Date: Date,
      Object: Object,
      Array: Array,
      Reflect: Reflect,
      S: new Proxy({}, { get(_, prop) { return prop; } }),

    };

    const jsStringPolyfill = {
      "charCodeAt": (s, i) => s.charCodeAt(i),
      "compare": (s1, s2) => {
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        return 0;
      },
      "concat": (s1, s2) => s1 + s2,
      "equals": (s1, s2) => s1 === s2,
      "fromCharCode": (i) => String.fromCharCode(i),
      "length": (s) => s.length,
      "substring": (s, a, b) => s.substring(a, b),
      "fromCharCodeArray": (a, start, end) => {
        if (end <= start) return '';

        const read = dartInstance.exports.$wasmI16ArrayGet;
        let result = '';
        let index = start;
        const chunkLength = Math.min(end - index, 500);
        let array = new Array(chunkLength);
        while (index < end) {
          const newChunkLength = Math.min(end - index, 500);
          for (let i = 0; i < newChunkLength; i++) {
            array[i] = read(a, index++);
          }
          if (newChunkLength < chunkLength) {
            array = array.slice(0, newChunkLength);
          }
          result += String.fromCharCode(...array);
        }
        return result;
      },
      "intoCharCodeArray": (s, a, start) => {
        if (s === '') return 0;

        const write = dartInstance.exports.$wasmI16ArraySet;
        for (var i = 0; i < s.length; ++i) {
          write(a, start++, s.charCodeAt(i));
        }
        return s.length;
      },
      "test": (s) => typeof s == "string",
    };


    

    dartInstance = await WebAssembly.instantiate(this.module, {
      ...baseImports,
      ...additionalImports,
      
      "wasm:js-string": jsStringPolyfill,
    });

    return new InstantiatedApp(this, dartInstance);
  }
}

class InstantiatedApp {
  constructor(compiledApp, instantiatedModule) {
    this.compiledApp = compiledApp;
    this.instantiatedModule = instantiatedModule;
  }

  // Call the main function with the given arguments.
  invokeMain(...args) {
    this.instantiatedModule.exports.$invokeMain(args);
  }
}

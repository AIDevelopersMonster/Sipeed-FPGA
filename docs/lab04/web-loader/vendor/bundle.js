// gen/openFPGALoader.mjs
async function instantiate(moduleArg = {}) {
  var moduleRtn;
  var Module = moduleArg;
  var ENVIRONMENT_IS_WEB = !!globalThis.window;
  var ENVIRONMENT_IS_WORKER = !!globalThis.WorkerGlobalScope;
  var ENVIRONMENT_IS_NODE = globalThis.process?.versions?.node && globalThis.process?.type != "renderer";
  var ENVIRONMENT_IS_PTHREAD = ENVIRONMENT_IS_WORKER && globalThis.name == "em-pthread";
  var arguments_ = [];
  var thisProgram = "./this.program";
  var quit_ = (status, toThrow) => {
    throw toThrow;
  };
  var _scriptName = import.meta.url;
  var scriptDirectory = "";
  function locateFile(path) {
    return scriptDirectory + path;
  }
  var readAsync, readBinary;
  if (ENVIRONMENT_IS_WEB || ENVIRONMENT_IS_WORKER) {
    try {
      scriptDirectory = new URL(".", _scriptName).href;
    } catch {
    }
    {
      if (ENVIRONMENT_IS_WORKER) {
        readBinary = (url) => {
          var xhr = new XMLHttpRequest();
          xhr.open("GET", url, false);
          xhr.responseType = "arraybuffer";
          xhr.send(null);
          return new Uint8Array(xhr.response);
        };
      }
      readAsync = async (url) => {
        var response = await fetch(url, { credentials: "same-origin" });
        if (response.ok) {
          return response.arrayBuffer();
        }
        throw new Error(response.status + " : " + response.url);
      };
    }
  } else {
  }
  var out = console.log.bind(console);
  var err = console.error.bind(console);
  var wasmBinary;
  var wasmModule;
  var ABORT = false;
  var EXITSTATUS;
  var readyPromiseResolve, readyPromiseReject;
  var startWorker;
  if (ENVIRONMENT_IS_PTHREAD) {
    let handleMessage = function(e) {
      try {
        var msgData = e["data"];
        var cmd = msgData.cmd;
        if (cmd === "load") {
          let messageQueue = [];
          self.onmessage = (e2) => messageQueue.push(e2);
          startWorker = () => {
            postMessage({ cmd: "loaded" });
            for (let msg of messageQueue) {
              handleMessage(msg);
            }
            self.onmessage = handleMessage;
          };
          for (const handler of msgData.handlers) {
            if (!Module[handler] || Module[handler].proxy) {
              Module[handler] = (...args) => {
                postMessage({ cmd: "callHandler", handler, args });
              };
              if (handler == "print")
                out = Module[handler];
              if (handler == "printErr")
                err = Module[handler];
            }
          }
          wasmMemory = msgData.wasmMemory;
          updateMemoryViews();
          wasmModule = msgData.wasmModule;
          createWasm();
          run();
        } else if (cmd === "run") {
          establishStackSpace(msgData.pthread_ptr);
          __emscripten_thread_init(msgData.pthread_ptr, 0, 0, 1, 0, 0);
          PThread.threadInitTLS();
          __emscripten_thread_mailbox_await(msgData.pthread_ptr);
          if (!initializedJS) {
            __embind_initialize_bindings();
            initializedJS = true;
          }
          try {
            invokeEntryPoint(msgData.start_routine, msgData.arg);
          } catch (ex) {
            if (ex != "unwind") {
              throw ex;
            }
          }
        } else if (msgData.target === "setimmediate") {
        } else if (cmd === "checkMailbox") {
          if (initializedJS) {
            checkMailbox();
          }
        } else if (cmd) {
          err(`worker: received unknown command ${cmd}`);
          err(msgData);
        }
      } catch (ex) {
        __emscripten_thread_crashed();
        throw ex;
      }
    };
    var initializedJS = false;
    self.onunhandledrejection = (e) => {
      throw e.reason || e;
    };
    self.onmessage = handleMessage;
  }
  var HEAP8, HEAPU8, HEAP16, HEAPU16, HEAP32, HEAPU32, HEAPF32, HEAPF64;
  var HEAP64, HEAPU64;
  var runtimeInitialized = false;
  var runtimeExited = false;
  function updateMemoryViews() {
    var b = wasmMemory.buffer;
    HEAP8 = new Int8Array(b);
    HEAP16 = new Int16Array(b);
    HEAPU8 = new Uint8Array(b);
    HEAPU16 = new Uint16Array(b);
    HEAP32 = new Int32Array(b);
    Module["HEAPU32"] = HEAPU32 = new Uint32Array(b);
    HEAPF32 = new Float32Array(b);
    HEAPF64 = new Float64Array(b);
    HEAP64 = new BigInt64Array(b);
    HEAPU64 = new BigUint64Array(b);
  }
  function initMemory() {
    if (ENVIRONMENT_IS_PTHREAD) {
      return;
    }
    {
      var INITIAL_MEMORY = 33554432;
      wasmMemory = new WebAssembly.Memory({ initial: INITIAL_MEMORY / 65536, maximum: INITIAL_MEMORY / 65536, shared: true });
    }
    updateMemoryViews();
  }
  function preRun() {
    callRuntimeCallbacks(onPreRuns);
  }
  function initRuntime() {
    runtimeInitialized = true;
    if (ENVIRONMENT_IS_PTHREAD)
      return startWorker();
    SOCKFS.root = FS.mount(SOCKFS, {}, null);
    if (!Module["noFSInit"] && !FS.initialized)
      FS.init();
    TTY.init();
    PIPEFS.root = FS.mount(PIPEFS, {}, null);
    wasmExports["fb"]();
    FS.ignorePermissions = false;
  }
  function preMain() {
  }
  function exitRuntime() {
    if (ENVIRONMENT_IS_PTHREAD) {
      return;
    }
    ___funcs_on_exit();
    FS.quit();
    TTY.shutdown();
    PThread.terminateAllThreads();
    runtimeExited = true;
  }
  function postRun() {
    if (ENVIRONMENT_IS_PTHREAD) {
      return;
    }
  }
  function abort(what) {
    what = "Aborted(" + what + ")";
    err(what);
    ABORT = true;
    what += ". Build with -sASSERTIONS for more info.";
    var e = new WebAssembly.RuntimeError(what);
    readyPromiseReject?.(e);
    throw e;
  }
  var wasmBinaryFile;
  function findWasmBinary() {
    if (Module["locateFile"]) {
      return locateFile("openFPGALoader.wasm");
    }
    return new URL("openFPGALoader.wasm", import.meta.url).href;
  }
  function getBinarySync(file) {
    if (readBinary) {
      return readBinary(file);
    }
    throw "both async and sync fetching of the wasm failed";
  }
  async function getWasmBinary(binaryFile) {
    if (!wasmBinary) {
      try {
        var response = await readAsync(binaryFile);
        return new Uint8Array(response);
      } catch {
      }
    }
    return getBinarySync(binaryFile);
  }
  async function instantiateArrayBuffer(binaryFile, imports) {
    try {
      var binary = await getWasmBinary(binaryFile);
      var instance = await WebAssembly.instantiate(binary, imports);
      return instance;
    } catch (reason) {
      err(`failed to asynchronously prepare wasm: ${reason}`);
      abort(reason);
    }
  }
  async function instantiateAsync(binary, binaryFile, imports) {
    if (!binary) {
      try {
        var response = fetch(binaryFile, { credentials: "same-origin" });
        var instantiationResult = await WebAssembly.instantiateStreaming(response, imports);
        return instantiationResult;
      } catch (reason) {
        err(`wasm streaming compile failed: ${reason}`);
        err("falling back to ArrayBuffer instantiation");
      }
    }
    return instantiateArrayBuffer(binaryFile, imports);
  }
  function getWasmImports() {
    assignWasmImports();
    var imports = { a: wasmImports };
    return imports;
  }
  async function createWasm() {
    function receiveInstance(instance2, module) {
      wasmExports = instance2.exports;
      wasmExports = Asyncify.instrumentWasmExports(wasmExports);
      registerTLSInit(wasmExports["rb"]);
      assignWasmExports(wasmExports);
      wasmModule = module;
      return wasmExports;
    }
    function receiveInstantiationResult(result2) {
      return receiveInstance(result2["instance"], result2["module"]);
    }
    var info = getWasmImports();
    if (ENVIRONMENT_IS_PTHREAD) {
      var instance = new WebAssembly.Instance(wasmModule, getWasmImports());
      return receiveInstance(instance, wasmModule);
    }
    wasmBinaryFile ??= findWasmBinary();
    var result = await instantiateAsync(wasmBinary, wasmBinaryFile, info);
    var exports = receiveInstantiationResult(result);
    return exports;
  }
  class ExitStatus {
    name = "ExitStatus";
    constructor(status) {
      this.message = `Program terminated with exit(${status})`;
      this.status = status;
    }
  }
  var terminateWorker = (worker) => {
    worker.terminate();
    worker.onmessage = (e) => {
    };
  };
  var cleanupThread = (pthread_ptr) => {
    var worker = PThread.pthreads[pthread_ptr];
    PThread.returnWorkerToPool(worker);
  };
  var callRuntimeCallbacks = (callbacks) => {
    while (callbacks.length > 0) {
      callbacks.shift()(Module);
    }
  };
  var onPreRuns = [];
  var spawnThread = (threadParams) => {
    var worker = PThread.getNewWorker();
    if (!worker) {
      return 6;
    }
    PThread.runningWorkers.push(worker);
    PThread.pthreads[threadParams.pthread_ptr] = worker;
    worker.pthread_ptr = threadParams.pthread_ptr;
    var msg = { cmd: "run", start_routine: threadParams.startRoutine, arg: threadParams.arg, pthread_ptr: threadParams.pthread_ptr };
    worker.postMessage(msg, threadParams.transferList);
    return 0;
  };
  var runtimeKeepaliveCounter = 0;
  var keepRuntimeAlive = () => runtimeKeepaliveCounter > 0;
  var stackSave = () => _emscripten_stack_get_current();
  var stackRestore = (val) => __emscripten_stack_restore(val);
  var stackAlloc = (sz) => __emscripten_stack_alloc(sz);
  var proxyToMainThread = (funcIndex, emAsmAddr, proxyMode, ...callArgs) => {
    var bufSize = 8 * callArgs.length * 2;
    var sp = stackSave();
    var args = stackAlloc(bufSize);
    var b = args >> 3;
    for (var arg of callArgs) {
      if (typeof arg == "bigint") {
        HEAP64[b++] = 1n;
        HEAP64[b++] = arg;
      } else {
        HEAP64[b++] = 0n;
        HEAPF64[b++] = arg;
      }
    }
    var rtn = __emscripten_run_js_on_main_thread(funcIndex, emAsmAddr, bufSize, args, proxyMode);
    stackRestore(sp);
    return rtn;
  };
  function _proc_exit(code) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(0, 0, 1, code);
    EXITSTATUS = code;
    if (!keepRuntimeAlive()) {
      PThread.terminateAllThreads();
      ABORT = true;
    }
    quit_(code, new ExitStatus(code));
  }
  function exitOnMainThread(returnCode) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(1, 0, 0, returnCode);
    _exit(returnCode);
  }
  var exitJS = (status, implicit) => {
    EXITSTATUS = status;
    if (ENVIRONMENT_IS_PTHREAD) {
      exitOnMainThread(status);
      throw "unwind";
    }
    if (!keepRuntimeAlive()) {
      exitRuntime();
    }
    _proc_exit(status);
  };
  var _exit = exitJS;
  var PThread = { unusedWorkers: [], runningWorkers: [], tlsInitFunctions: [], pthreads: {}, init() {
    if (!ENVIRONMENT_IS_PTHREAD) {
      PThread.initMainThread();
    }
  }, initMainThread() {
  }, terminateAllThreads: () => {
    for (var worker of PThread.runningWorkers) {
      terminateWorker(worker);
    }
    for (var worker of PThread.unusedWorkers) {
      terminateWorker(worker);
    }
    PThread.unusedWorkers = [];
    PThread.runningWorkers = [];
    PThread.pthreads = {};
  }, returnWorkerToPool: (worker) => {
    var pthread_ptr = worker.pthread_ptr;
    delete PThread.pthreads[pthread_ptr];
    PThread.unusedWorkers.push(worker);
    PThread.runningWorkers.splice(PThread.runningWorkers.indexOf(worker), 1);
    worker.pthread_ptr = 0;
    __emscripten_thread_free_data(pthread_ptr);
  }, threadInitTLS() {
    PThread.tlsInitFunctions.forEach((f) => f());
  }, loadWasmModuleToWorker: (worker) => new Promise((onFinishedLoading) => {
    worker.onmessage = (e) => {
      var d = e["data"];
      var cmd = d.cmd;
      if (d.targetThread && d.targetThread != _pthread_self()) {
        var targetWorker = PThread.pthreads[d.targetThread];
        if (targetWorker) {
          targetWorker.postMessage(d, d.transferList);
        } else {
          err(`Internal error! Worker sent a message "${cmd}" to target pthread ${d.targetThread}, but that thread no longer exists!`);
        }
        return;
      }
      if (cmd === "checkMailbox") {
        checkMailbox();
      } else if (cmd === "spawnThread") {
        spawnThread(d);
      } else if (cmd === "cleanupThread") {
        callUserCallback(() => cleanupThread(d.thread));
      } else if (cmd === "loaded") {
        worker.loaded = true;
        onFinishedLoading(worker);
      } else if (d.target === "setimmediate") {
        worker.postMessage(d);
      } else if (cmd === "callHandler") {
        Module[d.handler](...d.args);
      } else if (cmd) {
        err(`worker sent an unknown command ${cmd}`);
      }
    };
    worker.onerror = (e) => {
      var message = "worker sent an error!";
      err(`${message} ${e.filename}:${e.lineno}: ${e.message}`);
      throw e;
    };
    var handlers = [];
    var knownHandlers = [];
    for (var handler of knownHandlers) {
      if (Module.propertyIsEnumerable(handler)) {
        handlers.push(handler);
      }
    }
    worker.postMessage({ cmd: "load", handlers, wasmMemory, wasmModule });
  }), allocateUnusedWorker() {
    var worker;
    worker = new Worker(new URL("openFPGALoader.mjs", import.meta.url), { type: "module", name: "em-pthread" });
    PThread.unusedWorkers.push(worker);
  }, getNewWorker() {
    if (PThread.unusedWorkers.length == 0) {
      PThread.allocateUnusedWorker();
      PThread.loadWasmModuleToWorker(PThread.unusedWorkers[0]);
    }
    return PThread.unusedWorkers.pop();
  } };
  var dynCalls = {};
  function establishStackSpace(pthread_ptr) {
    var stackHigh = HEAPU32[pthread_ptr + 52 >> 2];
    var stackSize = HEAPU32[pthread_ptr + 56 >> 2];
    var stackLow = stackHigh - stackSize;
    _emscripten_stack_set_limits(stackHigh, stackLow);
    stackRestore(stackHigh);
  }
  var invokeEntryPoint = (ptr, arg) => {
    runtimeKeepaliveCounter = 0;
    var result = ((a1) => dynCall_ii(ptr, a1))(arg);
    function finish(result2) {
      if (keepRuntimeAlive()) {
        EXITSTATUS = result2;
        return;
      }
      __emscripten_thread_exit(result2);
    }
    finish(result);
  };
  var registerTLSInit = (tlsInitFunc) => PThread.tlsInitFunctions.push(tlsInitFunc);
  var wasmMemory;
  var UTF8Decoder = globalThis.TextDecoder && new TextDecoder();
  var findStringEnd = (heapOrArray, idx, maxBytesToRead, ignoreNul) => {
    var maxIdx = idx + maxBytesToRead;
    if (ignoreNul)
      return maxIdx;
    while (heapOrArray[idx] && !(idx >= maxIdx))
      ++idx;
    return idx;
  };
  var UTF8ArrayToString = (heapOrArray, idx = 0, maxBytesToRead, ignoreNul) => {
    var endPtr = findStringEnd(heapOrArray, idx, maxBytesToRead, ignoreNul);
    if (endPtr - idx > 16 && heapOrArray.buffer && UTF8Decoder) {
      return UTF8Decoder.decode(heapOrArray.buffer instanceof ArrayBuffer ? heapOrArray.subarray(idx, endPtr) : heapOrArray.slice(idx, endPtr));
    }
    var str = "";
    while (idx < endPtr) {
      var u0 = heapOrArray[idx++];
      if (!(u0 & 128)) {
        str += String.fromCharCode(u0);
        continue;
      }
      var u1 = heapOrArray[idx++] & 63;
      if ((u0 & 224) == 192) {
        str += String.fromCharCode((u0 & 31) << 6 | u1);
        continue;
      }
      var u2 = heapOrArray[idx++] & 63;
      if ((u0 & 240) == 224) {
        u0 = (u0 & 15) << 12 | u1 << 6 | u2;
      } else {
        u0 = (u0 & 7) << 18 | u1 << 12 | u2 << 6 | heapOrArray[idx++] & 63;
      }
      if (u0 < 65536) {
        str += String.fromCharCode(u0);
      } else {
        var ch = u0 - 65536;
        str += String.fromCharCode(55296 | ch >> 10, 56320 | ch & 1023);
      }
    }
    return str;
  };
  var UTF8ToString = (ptr, maxBytesToRead, ignoreNul) => ptr ? UTF8ArrayToString(HEAPU8, ptr, maxBytesToRead, ignoreNul) : "";
  var ___assert_fail = (condition, filename, line, func) => abort(`Assertion failed: ${UTF8ToString(condition)}, at: ` + [filename ? UTF8ToString(filename) : "unknown filename", line, func ? UTF8ToString(func) : "unknown function"]);
  var exceptionCaught = [];
  var uncaughtExceptionCount = 0;
  var ___cxa_begin_catch = (ptr) => {
    var info = new ExceptionInfo(ptr);
    if (!info.get_caught()) {
      info.set_caught(true);
      uncaughtExceptionCount--;
    }
    info.set_rethrown(false);
    exceptionCaught.push(info);
    return ___cxa_get_exception_ptr(ptr);
  };
  var exceptionLast = 0;
  var ___cxa_end_catch = () => {
    _setThrew(0, 0);
    var info = exceptionCaught.pop();
    ___cxa_decrement_exception_refcount(info.excPtr);
    exceptionLast = 0;
  };
  class ExceptionInfo {
    constructor(excPtr) {
      this.excPtr = excPtr;
      this.ptr = excPtr - 24;
    }
    set_type(type) {
      HEAPU32[this.ptr + 4 >> 2] = type;
    }
    get_type() {
      return HEAPU32[this.ptr + 4 >> 2];
    }
    set_destructor(destructor) {
      HEAPU32[this.ptr + 8 >> 2] = destructor;
    }
    get_destructor() {
      return HEAPU32[this.ptr + 8 >> 2];
    }
    set_caught(caught) {
      caught = caught ? 1 : 0;
      HEAP8[this.ptr + 12] = caught;
    }
    get_caught() {
      return HEAP8[this.ptr + 12] != 0;
    }
    set_rethrown(rethrown) {
      rethrown = rethrown ? 1 : 0;
      HEAP8[this.ptr + 13] = rethrown;
    }
    get_rethrown() {
      return HEAP8[this.ptr + 13] != 0;
    }
    init(type, destructor) {
      this.set_adjusted_ptr(0);
      this.set_type(type);
      this.set_destructor(destructor);
    }
    set_adjusted_ptr(adjustedPtr) {
      HEAPU32[this.ptr + 16 >> 2] = adjustedPtr;
    }
    get_adjusted_ptr() {
      return HEAPU32[this.ptr + 16 >> 2];
    }
  }
  var setTempRet0 = (val) => __emscripten_tempret_set(val);
  var findMatchingCatch = (args) => {
    var thrown = exceptionLast;
    if (!thrown) {
      setTempRet0(0);
      return 0;
    }
    var info = new ExceptionInfo(thrown);
    info.set_adjusted_ptr(thrown);
    var thrownType = info.get_type();
    if (!thrownType) {
      setTempRet0(0);
      return thrown;
    }
    for (var caughtType of args) {
      if (caughtType === 0 || caughtType === thrownType) {
        break;
      }
      var adjusted_ptr_addr = info.ptr + 16;
      if (___cxa_can_catch(caughtType, thrownType, adjusted_ptr_addr)) {
        setTempRet0(caughtType);
        return thrown;
      }
    }
    setTempRet0(thrownType);
    return thrown;
  };
  var ___cxa_find_matching_catch_2 = () => findMatchingCatch([]);
  var ___cxa_find_matching_catch_3 = (arg0) => findMatchingCatch([arg0]);
  var ___cxa_find_matching_catch_4 = (arg0, arg1) => findMatchingCatch([arg0, arg1]);
  var ___cxa_rethrow = () => {
    var info = exceptionCaught.pop();
    if (!info) {
      abort("no exception to throw");
    }
    var ptr = info.excPtr;
    if (!info.get_rethrown()) {
      exceptionCaught.push(info);
      info.set_rethrown(true);
      info.set_caught(false);
      uncaughtExceptionCount++;
    }
    ___cxa_increment_exception_refcount(ptr);
    exceptionLast = ptr;
    throw exceptionLast;
  };
  var ___cxa_throw = (ptr, type, destructor) => {
    var info = new ExceptionInfo(ptr);
    info.init(type, destructor);
    ___cxa_increment_exception_refcount(ptr);
    exceptionLast = ptr;
    uncaughtExceptionCount++;
    throw exceptionLast;
  };
  var ___cxa_uncaught_exceptions = () => uncaughtExceptionCount;
  function pthreadCreateProxied(pthread_ptr, attr, startRoutine, arg) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(2, 0, 1, pthread_ptr, attr, startRoutine, arg);
    return ___pthread_create_js(pthread_ptr, attr, startRoutine, arg);
  }
  var _emscripten_has_threading_support = () => !!globalThis.SharedArrayBuffer;
  var ___pthread_create_js = (pthread_ptr, attr, startRoutine, arg) => {
    if (!_emscripten_has_threading_support()) {
      return 6;
    }
    var transferList = [];
    var error = 0;
    if (ENVIRONMENT_IS_PTHREAD && (transferList.length === 0 || error)) {
      return pthreadCreateProxied(pthread_ptr, attr, startRoutine, arg);
    }
    if (error)
      return error;
    var threadParams = { startRoutine, pthread_ptr, arg, transferList };
    if (ENVIRONMENT_IS_PTHREAD) {
      threadParams.cmd = "spawnThread";
      postMessage(threadParams, transferList);
      return 0;
    }
    return spawnThread(threadParams);
  };
  var ___resumeException = (ptr) => {
    if (!exceptionLast) {
      exceptionLast = ptr;
    }
    throw exceptionLast;
  };
  var initRandomFill = () => (view) => view.set(crypto.getRandomValues(new Uint8Array(view.byteLength)));
  var randomFill = (view) => {
    (randomFill = initRandomFill())(view);
  };
  var PATH = { isAbs: (path) => path.charAt(0) === "/", splitPath: (filename) => {
    var splitPathRe = /^(\/?|)([\s\S]*?)((?:\.{1,2}|[^\/]+?|)(\.[^.\/]*|))(?:[\/]*)$/;
    return splitPathRe.exec(filename).slice(1);
  }, normalizeArray: (parts, allowAboveRoot) => {
    var up = 0;
    for (var i = parts.length - 1; i >= 0; i--) {
      var last = parts[i];
      if (last === ".") {
        parts.splice(i, 1);
      } else if (last === "..") {
        parts.splice(i, 1);
        up++;
      } else if (up) {
        parts.splice(i, 1);
        up--;
      }
    }
    if (allowAboveRoot) {
      for (; up; up--) {
        parts.unshift("..");
      }
    }
    return parts;
  }, normalize: (path) => {
    var isAbsolute = PATH.isAbs(path), trailingSlash = path.slice(-1) === "/";
    path = PATH.normalizeArray(path.split("/").filter((p) => !!p), !isAbsolute).join("/");
    if (!path && !isAbsolute) {
      path = ".";
    }
    if (path && trailingSlash) {
      path += "/";
    }
    return (isAbsolute ? "/" : "") + path;
  }, dirname: (path) => {
    var result = PATH.splitPath(path), root = result[0], dir = result[1];
    if (!root && !dir) {
      return ".";
    }
    if (dir) {
      dir = dir.slice(0, -1);
    }
    return root + dir;
  }, basename: (path) => path && path.match(/([^\/]+|\/)\/*$/)[1], join: (...paths) => PATH.normalize(paths.join("/")), join2: (l, r) => PATH.normalize(l + "/" + r) };
  var PATH_FS = { resolve: (...args) => {
    var resolvedPath = "", resolvedAbsolute = false;
    for (var i = args.length - 1; i >= -1 && !resolvedAbsolute; i--) {
      var path = i >= 0 ? args[i] : FS.cwd();
      if (typeof path != "string") {
        throw new TypeError("Arguments to path.resolve must be strings");
      } else if (!path) {
        return "";
      }
      resolvedPath = path + "/" + resolvedPath;
      resolvedAbsolute = PATH.isAbs(path);
    }
    resolvedPath = PATH.normalizeArray(resolvedPath.split("/").filter((p) => !!p), !resolvedAbsolute).join("/");
    return (resolvedAbsolute ? "/" : "") + resolvedPath || ".";
  }, relative: (from, to) => {
    from = PATH_FS.resolve(from).slice(1);
    to = PATH_FS.resolve(to).slice(1);
    function trim(arr) {
      var start = 0;
      for (; start < arr.length; start++) {
        if (arr[start] !== "")
          break;
      }
      var end = arr.length - 1;
      for (; end >= 0; end--) {
        if (arr[end] !== "")
          break;
      }
      if (start > end)
        return [];
      return arr.slice(start, end - start + 1);
    }
    var fromParts = trim(from.split("/"));
    var toParts = trim(to.split("/"));
    var length = Math.min(fromParts.length, toParts.length);
    var samePartsLength = length;
    for (var i = 0; i < length; i++) {
      if (fromParts[i] !== toParts[i]) {
        samePartsLength = i;
        break;
      }
    }
    var outputParts = [];
    for (var i = samePartsLength; i < fromParts.length; i++) {
      outputParts.push("..");
    }
    outputParts = outputParts.concat(toParts.slice(samePartsLength));
    return outputParts.join("/");
  } };
  var FS_stdin_getChar_buffer = [];
  var lengthBytesUTF8 = (str) => {
    var len = 0;
    for (var i = 0; i < str.length; ++i) {
      var c = str.charCodeAt(i);
      if (c <= 127) {
        len++;
      } else if (c <= 2047) {
        len += 2;
      } else if (c >= 55296 && c <= 57343) {
        len += 4;
        ++i;
      } else {
        len += 3;
      }
    }
    return len;
  };
  var stringToUTF8Array = (str, heap, outIdx, maxBytesToWrite) => {
    if (!(maxBytesToWrite > 0))
      return 0;
    var startIdx = outIdx;
    var endIdx = outIdx + maxBytesToWrite - 1;
    for (var i = 0; i < str.length; ++i) {
      var u = str.codePointAt(i);
      if (u <= 127) {
        if (outIdx >= endIdx)
          break;
        heap[outIdx++] = u;
      } else if (u <= 2047) {
        if (outIdx + 1 >= endIdx)
          break;
        heap[outIdx++] = 192 | u >> 6;
        heap[outIdx++] = 128 | u & 63;
      } else if (u <= 65535) {
        if (outIdx + 2 >= endIdx)
          break;
        heap[outIdx++] = 224 | u >> 12;
        heap[outIdx++] = 128 | u >> 6 & 63;
        heap[outIdx++] = 128 | u & 63;
      } else {
        if (outIdx + 3 >= endIdx)
          break;
        heap[outIdx++] = 240 | u >> 18;
        heap[outIdx++] = 128 | u >> 12 & 63;
        heap[outIdx++] = 128 | u >> 6 & 63;
        heap[outIdx++] = 128 | u & 63;
        i++;
      }
    }
    heap[outIdx] = 0;
    return outIdx - startIdx;
  };
  var intArrayFromString = (stringy, dontAddNull, length) => {
    var len = length > 0 ? length : lengthBytesUTF8(stringy) + 1;
    var u8array = new Array(len);
    var numBytesWritten = stringToUTF8Array(stringy, u8array, 0, u8array.length);
    if (dontAddNull)
      u8array.length = numBytesWritten;
    return u8array;
  };
  var FS_stdin_getChar = () => {
    if (!FS_stdin_getChar_buffer.length) {
      var result = null;
      {
      }
      if (!result) {
        return null;
      }
      FS_stdin_getChar_buffer = intArrayFromString(result, true);
    }
    return FS_stdin_getChar_buffer.shift();
  };
  var TTY = { ttys: [], init() {
  }, shutdown() {
  }, register(dev, ops) {
    TTY.ttys[dev] = { input: [], output: [], ops };
    FS.registerDevice(dev, TTY.stream_ops);
  }, stream_ops: { open(stream) {
    var tty = TTY.ttys[stream.node.rdev];
    if (!tty) {
      throw new FS.ErrnoError(43);
    }
    stream.tty = tty;
    stream.seekable = false;
  }, close(stream) {
    stream.tty.ops.fsync(stream.tty);
  }, fsync(stream) {
    stream.tty.ops.fsync(stream.tty);
  }, read(stream, buffer, offset, length, pos) {
    if (!stream.tty || !stream.tty.ops.get_char) {
      throw new FS.ErrnoError(60);
    }
    var bytesRead = 0;
    for (var i = 0; i < length; i++) {
      var result;
      try {
        result = stream.tty.ops.get_char(stream.tty);
      } catch (e) {
        throw new FS.ErrnoError(29);
      }
      if (result === void 0 && bytesRead === 0) {
        throw new FS.ErrnoError(6);
      }
      if (result === null || result === void 0)
        break;
      bytesRead++;
      buffer[offset + i] = result;
    }
    if (bytesRead) {
      stream.node.atime = Date.now();
    }
    return bytesRead;
  }, write(stream, buffer, offset, length, pos) {
    if (!stream.tty || !stream.tty.ops.put_char) {
      throw new FS.ErrnoError(60);
    }
    try {
      for (var i = 0; i < length; i++) {
        stream.tty.ops.put_char(stream.tty, buffer[offset + i]);
      }
    } catch (e) {
      throw new FS.ErrnoError(29);
    }
    if (length) {
      stream.node.mtime = stream.node.ctime = Date.now();
    }
    return i;
  } }, default_tty_ops: { get_char(tty) {
    return FS_stdin_getChar();
  }, put_char(tty, val) {
    if (val === null || val === 10) {
      out(UTF8ArrayToString(tty.output));
      tty.output = [];
    } else {
      if (val != 0)
        tty.output.push(val);
    }
  }, fsync(tty) {
    if (tty.output?.length > 0) {
      out(UTF8ArrayToString(tty.output));
      tty.output = [];
    }
  }, ioctl_tcgets(tty) {
    return { c_iflag: 25856, c_oflag: 5, c_cflag: 191, c_lflag: 35387, c_cc: [3, 28, 127, 21, 4, 0, 1, 0, 17, 19, 26, 0, 18, 15, 23, 22, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] };
  }, ioctl_tcsets(tty, optional_actions, data) {
    return 0;
  }, ioctl_tiocgwinsz(tty) {
    return [24, 80];
  } }, default_tty1_ops: { put_char(tty, val) {
    if (val === null || val === 10) {
      err(UTF8ArrayToString(tty.output));
      tty.output = [];
    } else {
      if (val != 0)
        tty.output.push(val);
    }
  }, fsync(tty) {
    if (tty.output?.length > 0) {
      err(UTF8ArrayToString(tty.output));
      tty.output = [];
    }
  } } };
  var mmapAlloc = (size) => {
    abort();
  };
  var MEMFS = { ops_table: null, mount(mount) {
    return MEMFS.createNode(null, "/", 16895, 0);
  }, createNode(parent, name, mode, dev) {
    if (FS.isBlkdev(mode) || FS.isFIFO(mode)) {
      throw new FS.ErrnoError(63);
    }
    MEMFS.ops_table ||= { dir: { node: { getattr: MEMFS.node_ops.getattr, setattr: MEMFS.node_ops.setattr, lookup: MEMFS.node_ops.lookup, mknod: MEMFS.node_ops.mknod, rename: MEMFS.node_ops.rename, unlink: MEMFS.node_ops.unlink, rmdir: MEMFS.node_ops.rmdir, readdir: MEMFS.node_ops.readdir, symlink: MEMFS.node_ops.symlink }, stream: { llseek: MEMFS.stream_ops.llseek } }, file: { node: { getattr: MEMFS.node_ops.getattr, setattr: MEMFS.node_ops.setattr }, stream: { llseek: MEMFS.stream_ops.llseek, read: MEMFS.stream_ops.read, write: MEMFS.stream_ops.write, mmap: MEMFS.stream_ops.mmap, msync: MEMFS.stream_ops.msync } }, link: { node: { getattr: MEMFS.node_ops.getattr, setattr: MEMFS.node_ops.setattr, readlink: MEMFS.node_ops.readlink }, stream: {} }, chrdev: { node: { getattr: MEMFS.node_ops.getattr, setattr: MEMFS.node_ops.setattr }, stream: FS.chrdev_stream_ops } };
    var node = FS.createNode(parent, name, mode, dev);
    if (FS.isDir(node.mode)) {
      node.node_ops = MEMFS.ops_table.dir.node;
      node.stream_ops = MEMFS.ops_table.dir.stream;
      node.contents = {};
    } else if (FS.isFile(node.mode)) {
      node.node_ops = MEMFS.ops_table.file.node;
      node.stream_ops = MEMFS.ops_table.file.stream;
      node.usedBytes = 0;
      node.contents = null;
    } else if (FS.isLink(node.mode)) {
      node.node_ops = MEMFS.ops_table.link.node;
      node.stream_ops = MEMFS.ops_table.link.stream;
    } else if (FS.isChrdev(node.mode)) {
      node.node_ops = MEMFS.ops_table.chrdev.node;
      node.stream_ops = MEMFS.ops_table.chrdev.stream;
    }
    node.atime = node.mtime = node.ctime = Date.now();
    if (parent) {
      parent.contents[name] = node;
      parent.atime = parent.mtime = parent.ctime = node.atime;
    }
    return node;
  }, getFileDataAsTypedArray(node) {
    if (!node.contents)
      return new Uint8Array(0);
    if (node.contents.subarray)
      return node.contents.subarray(0, node.usedBytes);
    return new Uint8Array(node.contents);
  }, expandFileStorage(node, newCapacity) {
    var prevCapacity = node.contents ? node.contents.length : 0;
    if (prevCapacity >= newCapacity)
      return;
    var CAPACITY_DOUBLING_MAX = 1024 * 1024;
    newCapacity = Math.max(newCapacity, prevCapacity * (prevCapacity < CAPACITY_DOUBLING_MAX ? 2 : 1.125) >>> 0);
    if (prevCapacity != 0)
      newCapacity = Math.max(newCapacity, 256);
    var oldContents = node.contents;
    node.contents = new Uint8Array(newCapacity);
    if (node.usedBytes > 0)
      node.contents.set(oldContents.subarray(0, node.usedBytes), 0);
  }, resizeFileStorage(node, newSize) {
    if (node.usedBytes == newSize)
      return;
    if (newSize == 0) {
      node.contents = null;
      node.usedBytes = 0;
    } else {
      var oldContents = node.contents;
      node.contents = new Uint8Array(newSize);
      if (oldContents) {
        node.contents.set(oldContents.subarray(0, Math.min(newSize, node.usedBytes)));
      }
      node.usedBytes = newSize;
    }
  }, node_ops: { getattr(node) {
    var attr = {};
    attr.dev = FS.isChrdev(node.mode) ? node.id : 1;
    attr.ino = node.id;
    attr.mode = node.mode;
    attr.nlink = 1;
    attr.uid = 0;
    attr.gid = 0;
    attr.rdev = node.rdev;
    if (FS.isDir(node.mode)) {
      attr.size = 4096;
    } else if (FS.isFile(node.mode)) {
      attr.size = node.usedBytes;
    } else if (FS.isLink(node.mode)) {
      attr.size = node.link.length;
    } else {
      attr.size = 0;
    }
    attr.atime = new Date(node.atime);
    attr.mtime = new Date(node.mtime);
    attr.ctime = new Date(node.ctime);
    attr.blksize = 4096;
    attr.blocks = Math.ceil(attr.size / attr.blksize);
    return attr;
  }, setattr(node, attr) {
    for (const key of ["mode", "atime", "mtime", "ctime"]) {
      if (attr[key] != null) {
        node[key] = attr[key];
      }
    }
    if (attr.size !== void 0) {
      MEMFS.resizeFileStorage(node, attr.size);
    }
  }, lookup(parent, name) {
    if (!MEMFS.doesNotExistError) {
      MEMFS.doesNotExistError = new FS.ErrnoError(44);
      MEMFS.doesNotExistError.stack = "<generic error, no stack>";
    }
    throw MEMFS.doesNotExistError;
  }, mknod(parent, name, mode, dev) {
    return MEMFS.createNode(parent, name, mode, dev);
  }, rename(old_node, new_dir, new_name) {
    var new_node;
    try {
      new_node = FS.lookupNode(new_dir, new_name);
    } catch (e) {
    }
    if (new_node) {
      if (FS.isDir(old_node.mode)) {
        for (var i in new_node.contents) {
          throw new FS.ErrnoError(55);
        }
      }
      FS.hashRemoveNode(new_node);
    }
    delete old_node.parent.contents[old_node.name];
    new_dir.contents[new_name] = old_node;
    old_node.name = new_name;
    new_dir.ctime = new_dir.mtime = old_node.parent.ctime = old_node.parent.mtime = Date.now();
  }, unlink(parent, name) {
    delete parent.contents[name];
    parent.ctime = parent.mtime = Date.now();
  }, rmdir(parent, name) {
    var node = FS.lookupNode(parent, name);
    for (var i in node.contents) {
      throw new FS.ErrnoError(55);
    }
    delete parent.contents[name];
    parent.ctime = parent.mtime = Date.now();
  }, readdir(node) {
    return [".", "..", ...Object.keys(node.contents)];
  }, symlink(parent, newname, oldpath) {
    var node = MEMFS.createNode(parent, newname, 511 | 40960, 0);
    node.link = oldpath;
    return node;
  }, readlink(node) {
    if (!FS.isLink(node.mode)) {
      throw new FS.ErrnoError(28);
    }
    return node.link;
  } }, stream_ops: { read(stream, buffer, offset, length, position) {
    var contents = stream.node.contents;
    if (position >= stream.node.usedBytes)
      return 0;
    var size = Math.min(stream.node.usedBytes - position, length);
    if (size > 8 && contents.subarray) {
      buffer.set(contents.subarray(position, position + size), offset);
    } else {
      for (var i = 0; i < size; i++)
        buffer[offset + i] = contents[position + i];
    }
    return size;
  }, write(stream, buffer, offset, length, position, canOwn) {
    if (!length)
      return 0;
    var node = stream.node;
    node.mtime = node.ctime = Date.now();
    if (buffer.subarray && (!node.contents || node.contents.subarray)) {
      if (canOwn) {
        node.contents = buffer.subarray(offset, offset + length);
        node.usedBytes = length;
        return length;
      } else if (node.usedBytes === 0 && position === 0) {
        node.contents = buffer.slice(offset, offset + length);
        node.usedBytes = length;
        return length;
      } else if (position + length <= node.usedBytes) {
        node.contents.set(buffer.subarray(offset, offset + length), position);
        return length;
      }
    }
    MEMFS.expandFileStorage(node, position + length);
    if (node.contents.subarray && buffer.subarray) {
      node.contents.set(buffer.subarray(offset, offset + length), position);
    } else {
      for (var i = 0; i < length; i++) {
        node.contents[position + i] = buffer[offset + i];
      }
    }
    node.usedBytes = Math.max(node.usedBytes, position + length);
    return length;
  }, llseek(stream, offset, whence) {
    var position = offset;
    if (whence === 1) {
      position += stream.position;
    } else if (whence === 2) {
      if (FS.isFile(stream.node.mode)) {
        position += stream.node.usedBytes;
      }
    }
    if (position < 0) {
      throw new FS.ErrnoError(28);
    }
    return position;
  }, mmap(stream, length, position, prot, flags) {
    if (!FS.isFile(stream.node.mode)) {
      throw new FS.ErrnoError(43);
    }
    var ptr;
    var allocated;
    var contents = stream.node.contents;
    if (!(flags & 2) && contents && contents.buffer === HEAP8.buffer) {
      allocated = false;
      ptr = contents.byteOffset;
    } else {
      allocated = true;
      ptr = mmapAlloc(length);
      if (!ptr) {
        throw new FS.ErrnoError(48);
      }
      if (contents) {
        if (position > 0 || position + length < contents.length) {
          if (contents.subarray) {
            contents = contents.subarray(position, position + length);
          } else {
            contents = Array.prototype.slice.call(contents, position, position + length);
          }
        }
        HEAP8.set(contents, ptr);
      }
    }
    return { ptr, allocated };
  }, msync(stream, buffer, offset, length, mmapFlags) {
    MEMFS.stream_ops.write(stream, buffer, 0, length, offset, false);
    return 0;
  } } };
  var FS_modeStringToFlags = (str) => {
    var flagModes = { r: 0, "r+": 2, w: 512 | 64 | 1, "w+": 512 | 64 | 2, a: 1024 | 64 | 1, "a+": 1024 | 64 | 2 };
    var flags = flagModes[str];
    if (typeof flags == "undefined") {
      throw new Error(`Unknown file open mode: ${str}`);
    }
    return flags;
  };
  var FS_getMode = (canRead, canWrite) => {
    var mode = 0;
    if (canRead)
      mode |= 292 | 73;
    if (canWrite)
      mode |= 146;
    return mode;
  };
  var asyncLoad = async (url) => {
    var arrayBuffer = await readAsync(url);
    return new Uint8Array(arrayBuffer);
  };
  var FS_createDataFile = (...args) => FS.createDataFile(...args);
  var getUniqueRunDependency = (id) => id;
  var runDependencies = 0;
  var dependenciesFulfilled = null;
  var removeRunDependency = (id) => {
    runDependencies--;
    if (runDependencies == 0) {
      if (dependenciesFulfilled) {
        var callback = dependenciesFulfilled;
        dependenciesFulfilled = null;
        callback();
      }
    }
  };
  var addRunDependency = (id) => {
    runDependencies++;
  };
  var preloadPlugins = [];
  var FS_handledByPreloadPlugin = async (byteArray, fullname) => {
    if (typeof Browser != "undefined")
      Browser.init();
    for (var plugin of preloadPlugins) {
      if (plugin["canHandle"](fullname)) {
        return plugin["handle"](byteArray, fullname);
      }
    }
    return byteArray;
  };
  var FS_preloadFile = async (parent, name, url, canRead, canWrite, dontCreateFile, canOwn, preFinish) => {
    var fullname = name ? PATH_FS.resolve(PATH.join2(parent, name)) : parent;
    var dep = getUniqueRunDependency(`cp ${fullname}`);
    addRunDependency(dep);
    try {
      var byteArray = url;
      if (typeof url == "string") {
        byteArray = await asyncLoad(url);
      }
      byteArray = await FS_handledByPreloadPlugin(byteArray, fullname);
      preFinish?.();
      if (!dontCreateFile) {
        FS_createDataFile(parent, name, byteArray, canRead, canWrite, canOwn);
      }
    } finally {
      removeRunDependency(dep);
    }
  };
  var FS_createPreloadedFile = (parent, name, url, canRead, canWrite, onload, onerror, dontCreateFile, canOwn, preFinish) => {
    FS_preloadFile(parent, name, url, canRead, canWrite, dontCreateFile, canOwn, preFinish).then(onload).catch(onerror);
  };
  var FS = { root: null, mounts: [], devices: {}, streams: [], nextInode: 1, nameTable: null, currentPath: "/", initialized: false, ignorePermissions: true, filesystems: null, syncFSRequests: 0, ErrnoError: class {
    name = "ErrnoError";
    constructor(errno) {
      this.errno = errno;
    }
  }, FSStream: class {
    shared = {};
    get object() {
      return this.node;
    }
    set object(val) {
      this.node = val;
    }
    get isRead() {
      return (this.flags & 2097155) !== 1;
    }
    get isWrite() {
      return (this.flags & 2097155) !== 0;
    }
    get isAppend() {
      return this.flags & 1024;
    }
    get flags() {
      return this.shared.flags;
    }
    set flags(val) {
      this.shared.flags = val;
    }
    get position() {
      return this.shared.position;
    }
    set position(val) {
      this.shared.position = val;
    }
  }, FSNode: class {
    node_ops = {};
    stream_ops = {};
    readMode = 292 | 73;
    writeMode = 146;
    mounted = null;
    constructor(parent, name, mode, rdev) {
      if (!parent) {
        parent = this;
      }
      this.parent = parent;
      this.mount = parent.mount;
      this.id = FS.nextInode++;
      this.name = name;
      this.mode = mode;
      this.rdev = rdev;
      this.atime = this.mtime = this.ctime = Date.now();
    }
    get read() {
      return (this.mode & this.readMode) === this.readMode;
    }
    set read(val) {
      val ? this.mode |= this.readMode : this.mode &= ~this.readMode;
    }
    get write() {
      return (this.mode & this.writeMode) === this.writeMode;
    }
    set write(val) {
      val ? this.mode |= this.writeMode : this.mode &= ~this.writeMode;
    }
    get isFolder() {
      return FS.isDir(this.mode);
    }
    get isDevice() {
      return FS.isChrdev(this.mode);
    }
  }, lookupPath(path, opts = {}) {
    if (!path) {
      throw new FS.ErrnoError(44);
    }
    opts.follow_mount ??= true;
    if (!PATH.isAbs(path)) {
      path = FS.cwd() + "/" + path;
    }
    linkloop:
      for (var nlinks = 0; nlinks < 40; nlinks++) {
        var parts = path.split("/").filter((p) => !!p);
        var current = FS.root;
        var current_path = "/";
        for (var i = 0; i < parts.length; i++) {
          var islast = i === parts.length - 1;
          if (islast && opts.parent) {
            break;
          }
          if (parts[i] === ".") {
            continue;
          }
          if (parts[i] === "..") {
            current_path = PATH.dirname(current_path);
            if (FS.isRoot(current)) {
              path = current_path + "/" + parts.slice(i + 1).join("/");
              nlinks--;
              continue linkloop;
            } else {
              current = current.parent;
            }
            continue;
          }
          current_path = PATH.join2(current_path, parts[i]);
          try {
            current = FS.lookupNode(current, parts[i]);
          } catch (e) {
            if (e?.errno === 44 && islast && opts.noent_okay) {
              return { path: current_path };
            }
            throw e;
          }
          if (FS.isMountpoint(current) && (!islast || opts.follow_mount)) {
            current = current.mounted.root;
          }
          if (FS.isLink(current.mode) && (!islast || opts.follow)) {
            if (!current.node_ops.readlink) {
              throw new FS.ErrnoError(52);
            }
            var link = current.node_ops.readlink(current);
            if (!PATH.isAbs(link)) {
              link = PATH.dirname(current_path) + "/" + link;
            }
            path = link + "/" + parts.slice(i + 1).join("/");
            continue linkloop;
          }
        }
        return { path: current_path, node: current };
      }
    throw new FS.ErrnoError(32);
  }, getPath(node) {
    var path;
    while (true) {
      if (FS.isRoot(node)) {
        var mount = node.mount.mountpoint;
        if (!path)
          return mount;
        return mount[mount.length - 1] !== "/" ? `${mount}/${path}` : mount + path;
      }
      path = path ? `${node.name}/${path}` : node.name;
      node = node.parent;
    }
  }, hashName(parentid, name) {
    var hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = (hash << 5) - hash + name.charCodeAt(i) | 0;
    }
    return (parentid + hash >>> 0) % FS.nameTable.length;
  }, hashAddNode(node) {
    var hash = FS.hashName(node.parent.id, node.name);
    node.name_next = FS.nameTable[hash];
    FS.nameTable[hash] = node;
  }, hashRemoveNode(node) {
    var hash = FS.hashName(node.parent.id, node.name);
    if (FS.nameTable[hash] === node) {
      FS.nameTable[hash] = node.name_next;
    } else {
      var current = FS.nameTable[hash];
      while (current) {
        if (current.name_next === node) {
          current.name_next = node.name_next;
          break;
        }
        current = current.name_next;
      }
    }
  }, lookupNode(parent, name) {
    var errCode = FS.mayLookup(parent);
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    var hash = FS.hashName(parent.id, name);
    for (var node = FS.nameTable[hash]; node; node = node.name_next) {
      var nodeName = node.name;
      if (node.parent.id === parent.id && nodeName === name) {
        return node;
      }
    }
    return FS.lookup(parent, name);
  }, createNode(parent, name, mode, rdev) {
    var node = new FS.FSNode(parent, name, mode, rdev);
    FS.hashAddNode(node);
    return node;
  }, destroyNode(node) {
    FS.hashRemoveNode(node);
  }, isRoot(node) {
    return node === node.parent;
  }, isMountpoint(node) {
    return !!node.mounted;
  }, isFile(mode) {
    return (mode & 61440) === 32768;
  }, isDir(mode) {
    return (mode & 61440) === 16384;
  }, isLink(mode) {
    return (mode & 61440) === 40960;
  }, isChrdev(mode) {
    return (mode & 61440) === 8192;
  }, isBlkdev(mode) {
    return (mode & 61440) === 24576;
  }, isFIFO(mode) {
    return (mode & 61440) === 4096;
  }, isSocket(mode) {
    return (mode & 49152) === 49152;
  }, flagsToPermissionString(flag) {
    var perms = ["r", "w", "rw"][flag & 3];
    if (flag & 512) {
      perms += "w";
    }
    return perms;
  }, nodePermissions(node, perms) {
    if (FS.ignorePermissions) {
      return 0;
    }
    if (perms.includes("r") && !(node.mode & 292)) {
      return 2;
    }
    if (perms.includes("w") && !(node.mode & 146)) {
      return 2;
    }
    if (perms.includes("x") && !(node.mode & 73)) {
      return 2;
    }
    return 0;
  }, mayLookup(dir) {
    if (!FS.isDir(dir.mode))
      return 54;
    var errCode = FS.nodePermissions(dir, "x");
    if (errCode)
      return errCode;
    if (!dir.node_ops.lookup)
      return 2;
    return 0;
  }, mayCreate(dir, name) {
    if (!FS.isDir(dir.mode)) {
      return 54;
    }
    try {
      var node = FS.lookupNode(dir, name);
      return 20;
    } catch (e) {
    }
    return FS.nodePermissions(dir, "wx");
  }, mayDelete(dir, name, isdir) {
    var node;
    try {
      node = FS.lookupNode(dir, name);
    } catch (e) {
      return e.errno;
    }
    var errCode = FS.nodePermissions(dir, "wx");
    if (errCode) {
      return errCode;
    }
    if (isdir) {
      if (!FS.isDir(node.mode)) {
        return 54;
      }
      if (FS.isRoot(node) || FS.getPath(node) === FS.cwd()) {
        return 10;
      }
    } else if (FS.isDir(node.mode)) {
      return 31;
    }
    return 0;
  }, mayOpen(node, flags) {
    if (!node) {
      return 44;
    }
    if (FS.isLink(node.mode)) {
      return 32;
    }
    var mode = FS.flagsToPermissionString(flags);
    if (FS.isDir(node.mode)) {
      if (mode !== "r" || flags & (512 | 64)) {
        return 31;
      }
    }
    return FS.nodePermissions(node, mode);
  }, checkOpExists(op, err2) {
    if (!op) {
      throw new FS.ErrnoError(err2);
    }
    return op;
  }, MAX_OPEN_FDS: 4096, nextfd() {
    for (var fd = 0; fd <= FS.MAX_OPEN_FDS; fd++) {
      if (!FS.streams[fd]) {
        return fd;
      }
    }
    throw new FS.ErrnoError(33);
  }, getStreamChecked(fd) {
    var stream = FS.getStream(fd);
    if (!stream) {
      throw new FS.ErrnoError(8);
    }
    return stream;
  }, getStream: (fd) => FS.streams[fd], createStream(stream, fd = -1) {
    stream = Object.assign(new FS.FSStream(), stream);
    if (fd == -1) {
      fd = FS.nextfd();
    }
    stream.fd = fd;
    FS.streams[fd] = stream;
    return stream;
  }, closeStream(fd) {
    FS.streams[fd] = null;
  }, dupStream(origStream, fd = -1) {
    var stream = FS.createStream(origStream, fd);
    stream.stream_ops?.dup?.(stream);
    return stream;
  }, doSetAttr(stream, node, attr) {
    var setattr = stream?.stream_ops.setattr;
    var arg = setattr ? stream : node;
    setattr ??= node.node_ops.setattr;
    FS.checkOpExists(setattr, 63);
    setattr(arg, attr);
  }, chrdev_stream_ops: { open(stream) {
    var device = FS.getDevice(stream.node.rdev);
    stream.stream_ops = device.stream_ops;
    stream.stream_ops.open?.(stream);
  }, llseek() {
    throw new FS.ErrnoError(70);
  } }, major: (dev) => dev >> 8, minor: (dev) => dev & 255, makedev: (ma, mi) => ma << 8 | mi, registerDevice(dev, ops) {
    FS.devices[dev] = { stream_ops: ops };
  }, getDevice: (dev) => FS.devices[dev], getMounts(mount) {
    var mounts = [];
    var check = [mount];
    while (check.length) {
      var m = check.pop();
      mounts.push(m);
      check.push(...m.mounts);
    }
    return mounts;
  }, syncfs(populate, callback) {
    if (typeof populate == "function") {
      callback = populate;
      populate = false;
    }
    FS.syncFSRequests++;
    if (FS.syncFSRequests > 1) {
      err(`warning: ${FS.syncFSRequests} FS.syncfs operations in flight at once, probably just doing extra work`);
    }
    var mounts = FS.getMounts(FS.root.mount);
    var completed = 0;
    function doCallback(errCode) {
      FS.syncFSRequests--;
      return callback(errCode);
    }
    function done(errCode) {
      if (errCode) {
        if (!done.errored) {
          done.errored = true;
          return doCallback(errCode);
        }
        return;
      }
      if (++completed >= mounts.length) {
        doCallback(null);
      }
    }
    for (var mount of mounts) {
      if (mount.type.syncfs) {
        mount.type.syncfs(mount, populate, done);
      } else {
        done(null);
      }
    }
  }, mount(type, opts, mountpoint) {
    var root = mountpoint === "/";
    var pseudo = !mountpoint;
    var node;
    if (root && FS.root) {
      throw new FS.ErrnoError(10);
    } else if (!root && !pseudo) {
      var lookup = FS.lookupPath(mountpoint, { follow_mount: false });
      mountpoint = lookup.path;
      node = lookup.node;
      if (FS.isMountpoint(node)) {
        throw new FS.ErrnoError(10);
      }
      if (!FS.isDir(node.mode)) {
        throw new FS.ErrnoError(54);
      }
    }
    var mount = { type, opts, mountpoint, mounts: [] };
    var mountRoot = type.mount(mount);
    mountRoot.mount = mount;
    mount.root = mountRoot;
    if (root) {
      FS.root = mountRoot;
    } else if (node) {
      node.mounted = mount;
      if (node.mount) {
        node.mount.mounts.push(mount);
      }
    }
    return mountRoot;
  }, unmount(mountpoint) {
    var lookup = FS.lookupPath(mountpoint, { follow_mount: false });
    if (!FS.isMountpoint(lookup.node)) {
      throw new FS.ErrnoError(28);
    }
    var node = lookup.node;
    var mount = node.mounted;
    var mounts = FS.getMounts(mount);
    for (var [hash, current] of Object.entries(FS.nameTable)) {
      while (current) {
        var next = current.name_next;
        if (mounts.includes(current.mount)) {
          FS.destroyNode(current);
        }
        current = next;
      }
    }
    node.mounted = null;
    var idx = node.mount.mounts.indexOf(mount);
    node.mount.mounts.splice(idx, 1);
  }, lookup(parent, name) {
    return parent.node_ops.lookup(parent, name);
  }, mknod(path, mode, dev) {
    var lookup = FS.lookupPath(path, { parent: true });
    var parent = lookup.node;
    var name = PATH.basename(path);
    if (!name) {
      throw new FS.ErrnoError(28);
    }
    if (name === "." || name === "..") {
      throw new FS.ErrnoError(20);
    }
    var errCode = FS.mayCreate(parent, name);
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    if (!parent.node_ops.mknod) {
      throw new FS.ErrnoError(63);
    }
    return parent.node_ops.mknod(parent, name, mode, dev);
  }, statfs(path) {
    return FS.statfsNode(FS.lookupPath(path, { follow: true }).node);
  }, statfsStream(stream) {
    return FS.statfsNode(stream.node);
  }, statfsNode(node) {
    var rtn = { bsize: 4096, frsize: 4096, blocks: 1e6, bfree: 5e5, bavail: 5e5, files: FS.nextInode, ffree: FS.nextInode - 1, fsid: 42, flags: 2, namelen: 255 };
    if (node.node_ops.statfs) {
      Object.assign(rtn, node.node_ops.statfs(node.mount.opts.root));
    }
    return rtn;
  }, create(path, mode = 438) {
    mode &= 4095;
    mode |= 32768;
    return FS.mknod(path, mode, 0);
  }, mkdir(path, mode = 511) {
    mode &= 511 | 512;
    mode |= 16384;
    return FS.mknod(path, mode, 0);
  }, mkdirTree(path, mode) {
    var dirs = path.split("/");
    var d = "";
    for (var dir of dirs) {
      if (!dir)
        continue;
      if (d || PATH.isAbs(path))
        d += "/";
      d += dir;
      try {
        FS.mkdir(d, mode);
      } catch (e) {
        if (e.errno != 20)
          throw e;
      }
    }
  }, mkdev(path, mode, dev) {
    if (typeof dev == "undefined") {
      dev = mode;
      mode = 438;
    }
    mode |= 8192;
    return FS.mknod(path, mode, dev);
  }, symlink(oldpath, newpath) {
    if (!PATH_FS.resolve(oldpath)) {
      throw new FS.ErrnoError(44);
    }
    var lookup = FS.lookupPath(newpath, { parent: true });
    var parent = lookup.node;
    if (!parent) {
      throw new FS.ErrnoError(44);
    }
    var newname = PATH.basename(newpath);
    var errCode = FS.mayCreate(parent, newname);
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    if (!parent.node_ops.symlink) {
      throw new FS.ErrnoError(63);
    }
    return parent.node_ops.symlink(parent, newname, oldpath);
  }, rename(old_path, new_path) {
    var old_dirname = PATH.dirname(old_path);
    var new_dirname = PATH.dirname(new_path);
    var old_name = PATH.basename(old_path);
    var new_name = PATH.basename(new_path);
    var lookup, old_dir, new_dir;
    lookup = FS.lookupPath(old_path, { parent: true });
    old_dir = lookup.node;
    lookup = FS.lookupPath(new_path, { parent: true });
    new_dir = lookup.node;
    if (!old_dir || !new_dir)
      throw new FS.ErrnoError(44);
    if (old_dir.mount !== new_dir.mount) {
      throw new FS.ErrnoError(75);
    }
    var old_node = FS.lookupNode(old_dir, old_name);
    var relative = PATH_FS.relative(old_path, new_dirname);
    if (relative.charAt(0) !== ".") {
      throw new FS.ErrnoError(28);
    }
    relative = PATH_FS.relative(new_path, old_dirname);
    if (relative.charAt(0) !== ".") {
      throw new FS.ErrnoError(55);
    }
    var new_node;
    try {
      new_node = FS.lookupNode(new_dir, new_name);
    } catch (e) {
    }
    if (old_node === new_node) {
      return;
    }
    var isdir = FS.isDir(old_node.mode);
    var errCode = FS.mayDelete(old_dir, old_name, isdir);
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    errCode = new_node ? FS.mayDelete(new_dir, new_name, isdir) : FS.mayCreate(new_dir, new_name);
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    if (!old_dir.node_ops.rename) {
      throw new FS.ErrnoError(63);
    }
    if (FS.isMountpoint(old_node) || new_node && FS.isMountpoint(new_node)) {
      throw new FS.ErrnoError(10);
    }
    if (new_dir !== old_dir) {
      errCode = FS.nodePermissions(old_dir, "w");
      if (errCode) {
        throw new FS.ErrnoError(errCode);
      }
    }
    FS.hashRemoveNode(old_node);
    try {
      old_dir.node_ops.rename(old_node, new_dir, new_name);
      old_node.parent = new_dir;
    } catch (e) {
      throw e;
    } finally {
      FS.hashAddNode(old_node);
    }
  }, rmdir(path) {
    var lookup = FS.lookupPath(path, { parent: true });
    var parent = lookup.node;
    var name = PATH.basename(path);
    var node = FS.lookupNode(parent, name);
    var errCode = FS.mayDelete(parent, name, true);
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    if (!parent.node_ops.rmdir) {
      throw new FS.ErrnoError(63);
    }
    if (FS.isMountpoint(node)) {
      throw new FS.ErrnoError(10);
    }
    parent.node_ops.rmdir(parent, name);
    FS.destroyNode(node);
  }, readdir(path) {
    var lookup = FS.lookupPath(path, { follow: true });
    var node = lookup.node;
    var readdir = FS.checkOpExists(node.node_ops.readdir, 54);
    return readdir(node);
  }, unlink(path) {
    var lookup = FS.lookupPath(path, { parent: true });
    var parent = lookup.node;
    if (!parent) {
      throw new FS.ErrnoError(44);
    }
    var name = PATH.basename(path);
    var node = FS.lookupNode(parent, name);
    var errCode = FS.mayDelete(parent, name, false);
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    if (!parent.node_ops.unlink) {
      throw new FS.ErrnoError(63);
    }
    if (FS.isMountpoint(node)) {
      throw new FS.ErrnoError(10);
    }
    parent.node_ops.unlink(parent, name);
    FS.destroyNode(node);
  }, readlink(path) {
    var lookup = FS.lookupPath(path);
    var link = lookup.node;
    if (!link) {
      throw new FS.ErrnoError(44);
    }
    if (!link.node_ops.readlink) {
      throw new FS.ErrnoError(28);
    }
    return link.node_ops.readlink(link);
  }, stat(path, dontFollow) {
    var lookup = FS.lookupPath(path, { follow: !dontFollow });
    var node = lookup.node;
    var getattr = FS.checkOpExists(node.node_ops.getattr, 63);
    return getattr(node);
  }, fstat(fd) {
    var stream = FS.getStreamChecked(fd);
    var node = stream.node;
    var getattr = stream.stream_ops.getattr;
    var arg = getattr ? stream : node;
    getattr ??= node.node_ops.getattr;
    FS.checkOpExists(getattr, 63);
    return getattr(arg);
  }, lstat(path) {
    return FS.stat(path, true);
  }, doChmod(stream, node, mode, dontFollow) {
    FS.doSetAttr(stream, node, { mode: mode & 4095 | node.mode & ~4095, ctime: Date.now(), dontFollow });
  }, chmod(path, mode, dontFollow) {
    var node;
    if (typeof path == "string") {
      var lookup = FS.lookupPath(path, { follow: !dontFollow });
      node = lookup.node;
    } else {
      node = path;
    }
    FS.doChmod(null, node, mode, dontFollow);
  }, lchmod(path, mode) {
    FS.chmod(path, mode, true);
  }, fchmod(fd, mode) {
    var stream = FS.getStreamChecked(fd);
    FS.doChmod(stream, stream.node, mode, false);
  }, doChown(stream, node, dontFollow) {
    FS.doSetAttr(stream, node, { timestamp: Date.now(), dontFollow });
  }, chown(path, uid, gid, dontFollow) {
    var node;
    if (typeof path == "string") {
      var lookup = FS.lookupPath(path, { follow: !dontFollow });
      node = lookup.node;
    } else {
      node = path;
    }
    FS.doChown(null, node, dontFollow);
  }, lchown(path, uid, gid) {
    FS.chown(path, uid, gid, true);
  }, fchown(fd, uid, gid) {
    var stream = FS.getStreamChecked(fd);
    FS.doChown(stream, stream.node, false);
  }, doTruncate(stream, node, len) {
    if (FS.isDir(node.mode)) {
      throw new FS.ErrnoError(31);
    }
    if (!FS.isFile(node.mode)) {
      throw new FS.ErrnoError(28);
    }
    var errCode = FS.nodePermissions(node, "w");
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    FS.doSetAttr(stream, node, { size: len, timestamp: Date.now() });
  }, truncate(path, len) {
    if (len < 0) {
      throw new FS.ErrnoError(28);
    }
    var node;
    if (typeof path == "string") {
      var lookup = FS.lookupPath(path, { follow: true });
      node = lookup.node;
    } else {
      node = path;
    }
    FS.doTruncate(null, node, len);
  }, ftruncate(fd, len) {
    var stream = FS.getStreamChecked(fd);
    if (len < 0 || (stream.flags & 2097155) === 0) {
      throw new FS.ErrnoError(28);
    }
    FS.doTruncate(stream, stream.node, len);
  }, utime(path, atime, mtime) {
    var lookup = FS.lookupPath(path, { follow: true });
    var node = lookup.node;
    var setattr = FS.checkOpExists(node.node_ops.setattr, 63);
    setattr(node, { atime, mtime });
  }, open(path, flags, mode = 438) {
    if (path === "") {
      throw new FS.ErrnoError(44);
    }
    flags = typeof flags == "string" ? FS_modeStringToFlags(flags) : flags;
    if (flags & 64) {
      mode = mode & 4095 | 32768;
    } else {
      mode = 0;
    }
    var node;
    var isDirPath;
    if (typeof path == "object") {
      node = path;
    } else {
      isDirPath = path.endsWith("/");
      var lookup = FS.lookupPath(path, { follow: !(flags & 131072), noent_okay: true });
      node = lookup.node;
      path = lookup.path;
    }
    var created = false;
    if (flags & 64) {
      if (node) {
        if (flags & 128) {
          throw new FS.ErrnoError(20);
        }
      } else if (isDirPath) {
        throw new FS.ErrnoError(31);
      } else {
        node = FS.mknod(path, mode | 511, 0);
        created = true;
      }
    }
    if (!node) {
      throw new FS.ErrnoError(44);
    }
    if (FS.isChrdev(node.mode)) {
      flags &= ~512;
    }
    if (flags & 65536 && !FS.isDir(node.mode)) {
      throw new FS.ErrnoError(54);
    }
    if (!created) {
      var errCode = FS.mayOpen(node, flags);
      if (errCode) {
        throw new FS.ErrnoError(errCode);
      }
    }
    if (flags & 512 && !created) {
      FS.truncate(node, 0);
    }
    flags &= ~(128 | 512 | 131072);
    var stream = FS.createStream({ node, path: FS.getPath(node), flags, seekable: true, position: 0, stream_ops: node.stream_ops, ungotten: [], error: false });
    if (stream.stream_ops.open) {
      stream.stream_ops.open(stream);
    }
    if (created) {
      FS.chmod(node, mode & 511);
    }
    return stream;
  }, close(stream) {
    if (FS.isClosed(stream)) {
      throw new FS.ErrnoError(8);
    }
    if (stream.getdents)
      stream.getdents = null;
    try {
      if (stream.stream_ops.close) {
        stream.stream_ops.close(stream);
      }
    } catch (e) {
      throw e;
    } finally {
      FS.closeStream(stream.fd);
    }
    stream.fd = null;
  }, isClosed(stream) {
    return stream.fd === null;
  }, llseek(stream, offset, whence) {
    if (FS.isClosed(stream)) {
      throw new FS.ErrnoError(8);
    }
    if (!stream.seekable || !stream.stream_ops.llseek) {
      throw new FS.ErrnoError(70);
    }
    if (whence != 0 && whence != 1 && whence != 2) {
      throw new FS.ErrnoError(28);
    }
    stream.position = stream.stream_ops.llseek(stream, offset, whence);
    stream.ungotten = [];
    return stream.position;
  }, read(stream, buffer, offset, length, position) {
    if (length < 0 || position < 0) {
      throw new FS.ErrnoError(28);
    }
    if (FS.isClosed(stream)) {
      throw new FS.ErrnoError(8);
    }
    if ((stream.flags & 2097155) === 1) {
      throw new FS.ErrnoError(8);
    }
    if (FS.isDir(stream.node.mode)) {
      throw new FS.ErrnoError(31);
    }
    if (!stream.stream_ops.read) {
      throw new FS.ErrnoError(28);
    }
    var seeking = typeof position != "undefined";
    if (!seeking) {
      position = stream.position;
    } else if (!stream.seekable) {
      throw new FS.ErrnoError(70);
    }
    var bytesRead = stream.stream_ops.read(stream, buffer, offset, length, position);
    if (!seeking)
      stream.position += bytesRead;
    return bytesRead;
  }, write(stream, buffer, offset, length, position, canOwn) {
    if (length < 0 || position < 0) {
      throw new FS.ErrnoError(28);
    }
    if (FS.isClosed(stream)) {
      throw new FS.ErrnoError(8);
    }
    if ((stream.flags & 2097155) === 0) {
      throw new FS.ErrnoError(8);
    }
    if (FS.isDir(stream.node.mode)) {
      throw new FS.ErrnoError(31);
    }
    if (!stream.stream_ops.write) {
      throw new FS.ErrnoError(28);
    }
    if (stream.seekable && stream.flags & 1024) {
      FS.llseek(stream, 0, 2);
    }
    var seeking = typeof position != "undefined";
    if (!seeking) {
      position = stream.position;
    } else if (!stream.seekable) {
      throw new FS.ErrnoError(70);
    }
    var bytesWritten = stream.stream_ops.write(stream, buffer, offset, length, position, canOwn);
    if (!seeking)
      stream.position += bytesWritten;
    return bytesWritten;
  }, mmap(stream, length, position, prot, flags) {
    if ((prot & 2) !== 0 && (flags & 2) === 0 && (stream.flags & 2097155) !== 2) {
      throw new FS.ErrnoError(2);
    }
    if ((stream.flags & 2097155) === 1) {
      throw new FS.ErrnoError(2);
    }
    if (!stream.stream_ops.mmap) {
      throw new FS.ErrnoError(43);
    }
    if (!length) {
      throw new FS.ErrnoError(28);
    }
    return stream.stream_ops.mmap(stream, length, position, prot, flags);
  }, msync(stream, buffer, offset, length, mmapFlags) {
    if (!stream.stream_ops.msync) {
      return 0;
    }
    return stream.stream_ops.msync(stream, buffer, offset, length, mmapFlags);
  }, ioctl(stream, cmd, arg) {
    if (!stream.stream_ops.ioctl) {
      throw new FS.ErrnoError(59);
    }
    return stream.stream_ops.ioctl(stream, cmd, arg);
  }, readFile(path, opts = {}) {
    opts.flags = opts.flags || 0;
    opts.encoding = opts.encoding || "binary";
    if (opts.encoding !== "utf8" && opts.encoding !== "binary") {
      abort(`Invalid encoding type "${opts.encoding}"`);
    }
    var stream = FS.open(path, opts.flags);
    var stat = FS.stat(path);
    var length = stat.size;
    var buf = new Uint8Array(length);
    FS.read(stream, buf, 0, length, 0);
    if (opts.encoding === "utf8") {
      buf = UTF8ArrayToString(buf);
    }
    FS.close(stream);
    return buf;
  }, writeFile(path, data, opts = {}) {
    opts.flags = opts.flags || 577;
    var stream = FS.open(path, opts.flags, opts.mode);
    if (typeof data == "string") {
      data = new Uint8Array(intArrayFromString(data, true));
    }
    if (ArrayBuffer.isView(data)) {
      FS.write(stream, data, 0, data.byteLength, void 0, opts.canOwn);
    } else {
      abort("Unsupported data type");
    }
    FS.close(stream);
  }, cwd: () => FS.currentPath, chdir(path) {
    var lookup = FS.lookupPath(path, { follow: true });
    if (lookup.node === null) {
      throw new FS.ErrnoError(44);
    }
    if (!FS.isDir(lookup.node.mode)) {
      throw new FS.ErrnoError(54);
    }
    var errCode = FS.nodePermissions(lookup.node, "x");
    if (errCode) {
      throw new FS.ErrnoError(errCode);
    }
    FS.currentPath = lookup.path;
  }, createDefaultDirectories() {
    FS.mkdir("/tmp");
    FS.mkdir("/home");
    FS.mkdir("/home/web_user");
  }, createDefaultDevices() {
    FS.mkdir("/dev");
    FS.registerDevice(FS.makedev(1, 3), { read: () => 0, write: (stream, buffer, offset, length, pos) => length, llseek: () => 0 });
    FS.mkdev("/dev/null", FS.makedev(1, 3));
    TTY.register(FS.makedev(5, 0), TTY.default_tty_ops);
    TTY.register(FS.makedev(6, 0), TTY.default_tty1_ops);
    FS.mkdev("/dev/tty", FS.makedev(5, 0));
    FS.mkdev("/dev/tty1", FS.makedev(6, 0));
    var randomBuffer = new Uint8Array(1024), randomLeft = 0;
    var randomByte = () => {
      if (randomLeft === 0) {
        randomFill(randomBuffer);
        randomLeft = randomBuffer.byteLength;
      }
      return randomBuffer[--randomLeft];
    };
    FS.createDevice("/dev", "random", randomByte);
    FS.createDevice("/dev", "urandom", randomByte);
    FS.mkdir("/dev/shm");
    FS.mkdir("/dev/shm/tmp");
  }, createSpecialDirectories() {
    FS.mkdir("/proc");
    var proc_self = FS.mkdir("/proc/self");
    FS.mkdir("/proc/self/fd");
    FS.mount({ mount() {
      var node = FS.createNode(proc_self, "fd", 16895, 73);
      node.stream_ops = { llseek: MEMFS.stream_ops.llseek };
      node.node_ops = { lookup(parent, name) {
        var fd = +name;
        var stream = FS.getStreamChecked(fd);
        var ret = { parent: null, mount: { mountpoint: "fake" }, node_ops: { readlink: () => stream.path }, id: fd + 1 };
        ret.parent = ret;
        return ret;
      }, readdir() {
        return Array.from(FS.streams.entries()).filter(([k, v]) => v).map(([k, v]) => k.toString());
      } };
      return node;
    } }, {}, "/proc/self/fd");
  }, createStandardStreams(input, output, error) {
    if (input) {
      FS.createDevice("/dev", "stdin", input);
    } else {
      FS.symlink("/dev/tty", "/dev/stdin");
    }
    if (output) {
      FS.createDevice("/dev", "stdout", null, output);
    } else {
      FS.symlink("/dev/tty", "/dev/stdout");
    }
    if (error) {
      FS.createDevice("/dev", "stderr", null, error);
    } else {
      FS.symlink("/dev/tty1", "/dev/stderr");
    }
    var stdin = FS.open("/dev/stdin", 0);
    var stdout = FS.open("/dev/stdout", 1);
    var stderr = FS.open("/dev/stderr", 1);
  }, staticInit() {
    FS.nameTable = new Array(4096);
    FS.mount(MEMFS, {}, "/");
    FS.createDefaultDirectories();
    FS.createDefaultDevices();
    FS.createSpecialDirectories();
    FS.filesystems = { MEMFS };
  }, init(input, output, error) {
    FS.initialized = true;
    FS.createStandardStreams(input, output, error);
  }, quit() {
    FS.initialized = false;
    _fflush(0);
    for (var stream of FS.streams) {
      if (stream) {
        FS.close(stream);
      }
    }
  }, findObject(path, dontResolveLastLink) {
    var ret = FS.analyzePath(path, dontResolveLastLink);
    if (!ret.exists) {
      return null;
    }
    return ret.object;
  }, analyzePath(path, dontResolveLastLink) {
    try {
      var lookup = FS.lookupPath(path, { follow: !dontResolveLastLink });
      path = lookup.path;
    } catch (e) {
    }
    var ret = { isRoot: false, exists: false, error: 0, name: null, path: null, object: null, parentExists: false, parentPath: null, parentObject: null };
    try {
      var lookup = FS.lookupPath(path, { parent: true });
      ret.parentExists = true;
      ret.parentPath = lookup.path;
      ret.parentObject = lookup.node;
      ret.name = PATH.basename(path);
      lookup = FS.lookupPath(path, { follow: !dontResolveLastLink });
      ret.exists = true;
      ret.path = lookup.path;
      ret.object = lookup.node;
      ret.name = lookup.node.name;
      ret.isRoot = lookup.path === "/";
    } catch (e) {
      ret.error = e.errno;
    }
    return ret;
  }, createPath(parent, path, canRead, canWrite) {
    parent = typeof parent == "string" ? parent : FS.getPath(parent);
    var parts = path.split("/").reverse();
    while (parts.length) {
      var part = parts.pop();
      if (!part)
        continue;
      var current = PATH.join2(parent, part);
      try {
        FS.mkdir(current);
      } catch (e) {
        if (e.errno != 20)
          throw e;
      }
      parent = current;
    }
    return current;
  }, createFile(parent, name, properties, canRead, canWrite) {
    var path = PATH.join2(typeof parent == "string" ? parent : FS.getPath(parent), name);
    var mode = FS_getMode(canRead, canWrite);
    return FS.create(path, mode);
  }, createDataFile(parent, name, data, canRead, canWrite, canOwn) {
    var path = name;
    if (parent) {
      parent = typeof parent == "string" ? parent : FS.getPath(parent);
      path = name ? PATH.join2(parent, name) : parent;
    }
    var mode = FS_getMode(canRead, canWrite);
    var node = FS.create(path, mode);
    if (data) {
      if (typeof data == "string") {
        var arr = new Array(data.length);
        for (var i = 0, len = data.length; i < len; ++i)
          arr[i] = data.charCodeAt(i);
        data = arr;
      }
      FS.chmod(node, mode | 146);
      var stream = FS.open(node, 577);
      FS.write(stream, data, 0, data.length, 0, canOwn);
      FS.close(stream);
      FS.chmod(node, mode);
    }
  }, createDevice(parent, name, input, output) {
    var path = PATH.join2(typeof parent == "string" ? parent : FS.getPath(parent), name);
    var mode = FS_getMode(!!input, !!output);
    FS.createDevice.major ??= 64;
    var dev = FS.makedev(FS.createDevice.major++, 0);
    FS.registerDevice(dev, { open(stream) {
      stream.seekable = false;
    }, close(stream) {
      if (output?.buffer?.length) {
        output(10);
      }
    }, read(stream, buffer, offset, length, pos) {
      var bytesRead = 0;
      for (var i = 0; i < length; i++) {
        var result;
        try {
          result = input();
        } catch (e) {
          throw new FS.ErrnoError(29);
        }
        if (result === void 0 && bytesRead === 0) {
          throw new FS.ErrnoError(6);
        }
        if (result === null || result === void 0)
          break;
        bytesRead++;
        buffer[offset + i] = result;
      }
      if (bytesRead) {
        stream.node.atime = Date.now();
      }
      return bytesRead;
    }, write(stream, buffer, offset, length, pos) {
      for (var i = 0; i < length; i++) {
        try {
          output(buffer[offset + i]);
        } catch (e) {
          throw new FS.ErrnoError(29);
        }
      }
      if (length) {
        stream.node.mtime = stream.node.ctime = Date.now();
      }
      return i;
    } });
    return FS.mkdev(path, mode, dev);
  }, forceLoadFile(obj) {
    if (obj.isDevice || obj.isFolder || obj.link || obj.contents)
      return true;
    if (globalThis.XMLHttpRequest) {
      abort("Lazy loading should have been performed (contents set) in createLazyFile, but it was not. Lazy loading only works in web workers. Use --embed-file or --preload-file in emcc on the main thread.");
    } else {
      try {
        obj.contents = readBinary(obj.url);
      } catch (e) {
        throw new FS.ErrnoError(29);
      }
    }
  }, createLazyFile(parent, name, url, canRead, canWrite) {
    class LazyUint8Array {
      lengthKnown = false;
      chunks = [];
      get(idx) {
        if (idx > this.length - 1 || idx < 0) {
          return void 0;
        }
        var chunkOffset = idx % this.chunkSize;
        var chunkNum = idx / this.chunkSize | 0;
        return this.getter(chunkNum)[chunkOffset];
      }
      setDataGetter(getter) {
        this.getter = getter;
      }
      cacheLength() {
        var xhr = new XMLHttpRequest();
        xhr.open("HEAD", url, false);
        xhr.send(null);
        if (!(xhr.status >= 200 && xhr.status < 300 || xhr.status === 304))
          abort("Couldn't load " + url + ". Status: " + xhr.status);
        var datalength = Number(xhr.getResponseHeader("Content-length"));
        var header;
        var hasByteServing = (header = xhr.getResponseHeader("Accept-Ranges")) && header === "bytes";
        var usesGzip = (header = xhr.getResponseHeader("Content-Encoding")) && header === "gzip";
        var chunkSize = 1024 * 1024;
        if (!hasByteServing)
          chunkSize = datalength;
        var doXHR = (from, to) => {
          if (from > to)
            abort("invalid range (" + from + ", " + to + ") or no bytes requested!");
          if (to > datalength - 1)
            abort("only " + datalength + " bytes available! programmer error!");
          var xhr2 = new XMLHttpRequest();
          xhr2.open("GET", url, false);
          if (datalength !== chunkSize)
            xhr2.setRequestHeader("Range", "bytes=" + from + "-" + to);
          xhr2.responseType = "arraybuffer";
          if (xhr2.overrideMimeType) {
            xhr2.overrideMimeType("text/plain; charset=x-user-defined");
          }
          xhr2.send(null);
          if (!(xhr2.status >= 200 && xhr2.status < 300 || xhr2.status === 304))
            abort("Couldn't load " + url + ". Status: " + xhr2.status);
          if (xhr2.response !== void 0) {
            return new Uint8Array(xhr2.response || []);
          }
          return intArrayFromString(xhr2.responseText || "", true);
        };
        var lazyArray2 = this;
        lazyArray2.setDataGetter((chunkNum) => {
          var start = chunkNum * chunkSize;
          var end = (chunkNum + 1) * chunkSize - 1;
          end = Math.min(end, datalength - 1);
          if (typeof lazyArray2.chunks[chunkNum] == "undefined") {
            lazyArray2.chunks[chunkNum] = doXHR(start, end);
          }
          if (typeof lazyArray2.chunks[chunkNum] == "undefined")
            abort("doXHR failed!");
          return lazyArray2.chunks[chunkNum];
        });
        if (usesGzip || !datalength) {
          chunkSize = datalength = 1;
          datalength = this.getter(0).length;
          chunkSize = datalength;
          out("LazyFiles on gzip forces download of the whole file when length is accessed");
        }
        this._length = datalength;
        this._chunkSize = chunkSize;
        this.lengthKnown = true;
      }
      get length() {
        if (!this.lengthKnown) {
          this.cacheLength();
        }
        return this._length;
      }
      get chunkSize() {
        if (!this.lengthKnown) {
          this.cacheLength();
        }
        return this._chunkSize;
      }
    }
    if (globalThis.XMLHttpRequest) {
      if (!ENVIRONMENT_IS_WORKER)
        abort("Cannot do synchronous binary XHRs outside webworkers in modern browsers. Use --embed-file or --preload-file in emcc");
      var lazyArray = new LazyUint8Array();
      var properties = { isDevice: false, contents: lazyArray };
    } else {
      var properties = { isDevice: false, url };
    }
    var node = FS.createFile(parent, name, properties, canRead, canWrite);
    if (properties.contents) {
      node.contents = properties.contents;
    } else if (properties.url) {
      node.contents = null;
      node.url = properties.url;
    }
    Object.defineProperties(node, { usedBytes: { get: function() {
      return this.contents.length;
    } } });
    var stream_ops = {};
    for (const [key, fn] of Object.entries(node.stream_ops)) {
      stream_ops[key] = (...args) => {
        FS.forceLoadFile(node);
        return fn(...args);
      };
    }
    function writeChunks(stream, buffer, offset, length, position) {
      var contents = stream.node.contents;
      if (position >= contents.length)
        return 0;
      var size = Math.min(contents.length - position, length);
      if (contents.slice) {
        for (var i = 0; i < size; i++) {
          buffer[offset + i] = contents[position + i];
        }
      } else {
        for (var i = 0; i < size; i++) {
          buffer[offset + i] = contents.get(position + i);
        }
      }
      return size;
    }
    stream_ops.read = (stream, buffer, offset, length, position) => {
      FS.forceLoadFile(node);
      return writeChunks(stream, buffer, offset, length, position);
    };
    stream_ops.mmap = (stream, length, position, prot, flags) => {
      FS.forceLoadFile(node);
      var ptr = mmapAlloc(length);
      if (!ptr) {
        throw new FS.ErrnoError(48);
      }
      writeChunks(stream, HEAP8, ptr, length, position);
      return { ptr, allocated: true };
    };
    node.stream_ops = stream_ops;
    return node;
  } };
  var SOCKFS = { callbacks: {}, on(event, callback) {
    SOCKFS.callbacks[event] = callback;
  }, emit(event, param) {
    SOCKFS.callbacks[event]?.(param);
  }, mount(mount) {
    return FS.createNode(null, "/", 16895, 0);
  }, createSocket(family, type, protocol) {
    if (family != 2) {
      throw new FS.ErrnoError(5);
    }
    type &= ~526336;
    if (type != 1 && type != 2) {
      throw new FS.ErrnoError(28);
    }
    var streaming = type == 1;
    if (streaming && protocol && protocol != 6) {
      throw new FS.ErrnoError(66);
    }
    var sock = { family, type, protocol, server: null, error: null, peers: {}, pending: [], recv_queue: [], sock_ops: SOCKFS.websocket_sock_ops };
    var name = SOCKFS.nextname();
    var node = FS.createNode(SOCKFS.root, name, 49152, 0);
    node.sock = sock;
    var stream = FS.createStream({ path: name, node, flags: 2, seekable: false, stream_ops: SOCKFS.stream_ops });
    sock.stream = stream;
    return sock;
  }, getSocket(fd) {
    var stream = FS.getStream(fd);
    if (!stream || !FS.isSocket(stream.node.mode)) {
      return null;
    }
    return stream.node.sock;
  }, stream_ops: { poll(stream) {
    var sock = stream.node.sock;
    return sock.sock_ops.poll(sock);
  }, ioctl(stream, request, varargs) {
    var sock = stream.node.sock;
    return sock.sock_ops.ioctl(sock, request, varargs);
  }, read(stream, buffer, offset, length, position) {
    var sock = stream.node.sock;
    var msg = sock.sock_ops.recvmsg(sock, length);
    if (!msg) {
      return 0;
    }
    buffer.set(msg.buffer, offset);
    return msg.buffer.length;
  }, write(stream, buffer, offset, length, position) {
    var sock = stream.node.sock;
    return sock.sock_ops.sendmsg(sock, buffer, offset, length);
  }, close(stream) {
    var sock = stream.node.sock;
    sock.sock_ops.close(sock);
  } }, nextname() {
    if (!SOCKFS.nextname.current) {
      SOCKFS.nextname.current = 0;
    }
    return `socket[${SOCKFS.nextname.current++}]`;
  }, websocket_sock_ops: { createPeer(sock, addr, port) {
    var ws;
    if (typeof addr == "object") {
      ws = addr;
      addr = null;
      port = null;
    }
    if (ws) {
      if (ws._socket) {
        addr = ws._socket.remoteAddress;
        port = ws._socket.remotePort;
      } else {
        var result = /ws[s]?:\/\/([^:]+):(\d+)/.exec(ws.url);
        if (!result) {
          throw new Error("WebSocket URL must be in the format ws(s)://address:port");
        }
        addr = result[1];
        port = parseInt(result[2], 10);
      }
    } else {
      try {
        var url = "ws://".replace("#", "//");
        var subProtocols = "binary";
        var opts = void 0;
        if (url === "ws://" || url === "wss://") {
          var parts = addr.split("/");
          url = url + parts[0] + ":" + port + "/" + parts.slice(1).join("/");
        }
        if (subProtocols !== "null") {
          subProtocols = subProtocols.replace(/^ +| +$/g, "").split(/ *, */);
          opts = subProtocols;
        }
        var WebSocketConstructor;
        {
          WebSocketConstructor = WebSocket;
        }
        ws = new WebSocketConstructor(url, opts);
        ws.binaryType = "arraybuffer";
      } catch (e) {
        throw new FS.ErrnoError(23);
      }
    }
    var peer = { addr, port, socket: ws, msg_send_queue: [] };
    SOCKFS.websocket_sock_ops.addPeer(sock, peer);
    SOCKFS.websocket_sock_ops.handlePeerEvents(sock, peer);
    if (sock.type === 2 && typeof sock.sport != "undefined") {
      peer.msg_send_queue.push(new Uint8Array([255, 255, 255, 255, "p".charCodeAt(0), "o".charCodeAt(0), "r".charCodeAt(0), "t".charCodeAt(0), (sock.sport & 65280) >> 8, sock.sport & 255]));
    }
    return peer;
  }, getPeer(sock, addr, port) {
    return sock.peers[addr + ":" + port];
  }, addPeer(sock, peer) {
    sock.peers[peer.addr + ":" + peer.port] = peer;
  }, removePeer(sock, peer) {
    delete sock.peers[peer.addr + ":" + peer.port];
  }, handlePeerEvents(sock, peer) {
    var first = true;
    var handleOpen = function() {
      sock.connecting = false;
      SOCKFS.emit("open", sock.stream.fd);
      try {
        var queued = peer.msg_send_queue.shift();
        while (queued) {
          peer.socket.send(queued);
          queued = peer.msg_send_queue.shift();
        }
      } catch (e) {
        peer.socket.close();
      }
    };
    function handleMessage(data) {
      if (typeof data == "string") {
        var encoder = new TextEncoder();
        data = encoder.encode(data);
      } else {
        if (data.byteLength == 0) {
          return;
        }
        data = new Uint8Array(data);
      }
      var wasfirst = first;
      first = false;
      if (wasfirst && data.length === 10 && data[0] === 255 && data[1] === 255 && data[2] === 255 && data[3] === 255 && data[4] === "p".charCodeAt(0) && data[5] === "o".charCodeAt(0) && data[6] === "r".charCodeAt(0) && data[7] === "t".charCodeAt(0)) {
        var newport = data[8] << 8 | data[9];
        SOCKFS.websocket_sock_ops.removePeer(sock, peer);
        peer.port = newport;
        SOCKFS.websocket_sock_ops.addPeer(sock, peer);
        return;
      }
      sock.recv_queue.push({ addr: peer.addr, port: peer.port, data });
      SOCKFS.emit("message", sock.stream.fd);
    }
    if (ENVIRONMENT_IS_NODE) {
      peer.socket.on("open", handleOpen);
      peer.socket.on("message", function(data, isBinary) {
        if (!isBinary) {
          return;
        }
        handleMessage(new Uint8Array(data).buffer);
      });
      peer.socket.on("close", function() {
        SOCKFS.emit("close", sock.stream.fd);
      });
      peer.socket.on("error", function(error) {
        sock.error = 14;
        SOCKFS.emit("error", [sock.stream.fd, sock.error, "ECONNREFUSED: Connection refused"]);
      });
    } else {
      peer.socket.onopen = handleOpen;
      peer.socket.onclose = function() {
        SOCKFS.emit("close", sock.stream.fd);
      };
      peer.socket.onmessage = function peer_socket_onmessage(event) {
        handleMessage(event.data);
      };
      peer.socket.onerror = function(error) {
        sock.error = 14;
        SOCKFS.emit("error", [sock.stream.fd, sock.error, "ECONNREFUSED: Connection refused"]);
      };
    }
  }, poll(sock) {
    if (sock.type === 1 && sock.server) {
      return sock.pending.length ? 64 | 1 : 0;
    }
    var mask = 0;
    var dest = sock.type === 1 ? SOCKFS.websocket_sock_ops.getPeer(sock, sock.daddr, sock.dport) : null;
    if (sock.recv_queue.length || !dest || dest && dest.socket.readyState === dest.socket.CLOSING || dest && dest.socket.readyState === dest.socket.CLOSED) {
      mask |= 64 | 1;
    }
    if (!dest || dest && dest.socket.readyState === dest.socket.OPEN) {
      mask |= 4;
    }
    if (dest && dest.socket.readyState === dest.socket.CLOSING || dest && dest.socket.readyState === dest.socket.CLOSED) {
      if (sock.connecting) {
        mask |= 4;
      } else {
        mask |= 16;
      }
    }
    return mask;
  }, ioctl(sock, request, arg) {
    switch (request) {
      case 21531:
        var bytes = 0;
        if (sock.recv_queue.length) {
          bytes = sock.recv_queue[0].data.length;
        }
        HEAP32[arg >> 2] = bytes;
        return 0;
      case 21537:
        var on = HEAP32[arg >> 2];
        if (on) {
          sock.stream.flags |= 2048;
        } else {
          sock.stream.flags &= ~2048;
        }
        return 0;
      default:
        return 28;
    }
  }, close(sock) {
    if (sock.server) {
      try {
        sock.server.close();
      } catch (e) {
      }
      sock.server = null;
    }
    for (var peer of Object.values(sock.peers)) {
      try {
        peer.socket.close();
      } catch (e) {
      }
      SOCKFS.websocket_sock_ops.removePeer(sock, peer);
    }
    return 0;
  }, bind(sock, addr, port) {
    if (typeof sock.saddr != "undefined" || typeof sock.sport != "undefined") {
      throw new FS.ErrnoError(28);
    }
    sock.saddr = addr;
    sock.sport = port;
    if (sock.type === 2) {
      if (sock.server) {
        sock.server.close();
        sock.server = null;
      }
      try {
        sock.sock_ops.listen(sock, 0);
      } catch (e) {
        if (!(e.name === "ErrnoError"))
          throw e;
        if (e.errno !== 138)
          throw e;
      }
    }
  }, connect(sock, addr, port) {
    if (sock.server) {
      throw new FS.ErrnoError(138);
    }
    if (typeof sock.daddr != "undefined" && typeof sock.dport != "undefined") {
      var dest = SOCKFS.websocket_sock_ops.getPeer(sock, sock.daddr, sock.dport);
      if (dest) {
        if (dest.socket.readyState === dest.socket.CONNECTING) {
          throw new FS.ErrnoError(7);
        } else {
          throw new FS.ErrnoError(30);
        }
      }
    }
    var peer = SOCKFS.websocket_sock_ops.createPeer(sock, addr, port);
    sock.daddr = peer.addr;
    sock.dport = peer.port;
    sock.connecting = true;
  }, listen(sock, backlog) {
    if (!ENVIRONMENT_IS_NODE) {
      throw new FS.ErrnoError(138);
    }
  }, accept(listensock) {
    if (!listensock.server || !listensock.pending.length) {
      throw new FS.ErrnoError(28);
    }
    var newsock = listensock.pending.shift();
    newsock.stream.flags = listensock.stream.flags;
    return newsock;
  }, getname(sock, peer) {
    var addr, port;
    if (peer) {
      if (sock.daddr === void 0 || sock.dport === void 0) {
        throw new FS.ErrnoError(53);
      }
      addr = sock.daddr;
      port = sock.dport;
    } else {
      addr = sock.saddr || 0;
      port = sock.sport || 0;
    }
    return { addr, port };
  }, sendmsg(sock, buffer, offset, length, addr, port) {
    if (sock.type === 2) {
      if (addr === void 0 || port === void 0) {
        addr = sock.daddr;
        port = sock.dport;
      }
      if (addr === void 0 || port === void 0) {
        throw new FS.ErrnoError(17);
      }
    } else {
      addr = sock.daddr;
      port = sock.dport;
    }
    var dest = SOCKFS.websocket_sock_ops.getPeer(sock, addr, port);
    if (sock.type === 1) {
      if (!dest || dest.socket.readyState === dest.socket.CLOSING || dest.socket.readyState === dest.socket.CLOSED) {
        throw new FS.ErrnoError(53);
      }
    }
    if (ArrayBuffer.isView(buffer)) {
      offset += buffer.byteOffset;
      buffer = buffer.buffer;
    }
    var data = buffer.slice(offset, offset + length);
    if (data instanceof SharedArrayBuffer) {
      data = new Uint8Array(new Uint8Array(data)).buffer;
    }
    if (!dest || dest.socket.readyState !== dest.socket.OPEN) {
      if (sock.type === 2) {
        if (!dest || dest.socket.readyState === dest.socket.CLOSING || dest.socket.readyState === dest.socket.CLOSED) {
          dest = SOCKFS.websocket_sock_ops.createPeer(sock, addr, port);
        }
      }
      dest.msg_send_queue.push(data);
      return length;
    }
    try {
      dest.socket.send(data);
      return length;
    } catch (e) {
      throw new FS.ErrnoError(28);
    }
  }, recvmsg(sock, length) {
    if (sock.type === 1 && sock.server) {
      throw new FS.ErrnoError(53);
    }
    var queued = sock.recv_queue.shift();
    if (!queued) {
      if (sock.type === 1) {
        var dest = SOCKFS.websocket_sock_ops.getPeer(sock, sock.daddr, sock.dport);
        if (!dest) {
          throw new FS.ErrnoError(53);
        }
        if (dest.socket.readyState === dest.socket.CLOSING || dest.socket.readyState === dest.socket.CLOSED) {
          return null;
        }
        throw new FS.ErrnoError(6);
      }
      throw new FS.ErrnoError(6);
    }
    var queuedLength = queued.data.byteLength || queued.data.length;
    var queuedOffset = queued.data.byteOffset || 0;
    var queuedBuffer = queued.data.buffer || queued.data;
    var bytesRead = Math.min(length, queuedLength);
    var res = { buffer: new Uint8Array(queuedBuffer, queuedOffset, bytesRead), addr: queued.addr, port: queued.port };
    if (sock.type === 1 && bytesRead < queuedLength) {
      var bytesRemaining = queuedLength - bytesRead;
      queued.data = new Uint8Array(queuedBuffer, queuedOffset + bytesRead, bytesRemaining);
      sock.recv_queue.unshift(queued);
    }
    return res;
  } } };
  var getSocketFromFD = (fd) => {
    var socket = SOCKFS.getSocket(fd);
    if (!socket)
      throw new FS.ErrnoError(8);
    return socket;
  };
  var inetPton4 = (str) => {
    var b = str.split(".");
    for (var i = 0; i < 4; i++) {
      var tmp = Number(b[i]);
      if (isNaN(tmp))
        return null;
      b[i] = tmp;
    }
    return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0;
  };
  var inetPton6 = (str) => {
    var words;
    var w, offset, z;
    var valid6regx = /^((?=.*::)(?!.*::.+::)(::)?([\dA-F]{1,4}:(:|\b)|){5}|([\dA-F]{1,4}:){6})((([\dA-F]{1,4}((?!\3)::|:\b|$))|(?!\2\3)){2}|(((2[0-4]|1\d|[1-9])?\d|25[0-5])\.?\b){4})$/i;
    var parts = [];
    if (!valid6regx.test(str)) {
      return null;
    }
    if (str === "::") {
      return [0, 0, 0, 0, 0, 0, 0, 0];
    }
    if (str.startsWith("::")) {
      str = str.replace("::", "Z:");
    } else {
      str = str.replace("::", ":Z:");
    }
    if (str.indexOf(".") > 0) {
      str = str.replace(new RegExp("[.]", "g"), ":");
      words = str.split(":");
      words[words.length - 4] = Number(words[words.length - 4]) + Number(words[words.length - 3]) * 256;
      words[words.length - 3] = Number(words[words.length - 2]) + Number(words[words.length - 1]) * 256;
      words = words.slice(0, words.length - 2);
    } else {
      words = str.split(":");
    }
    offset = 0;
    z = 0;
    for (w = 0; w < words.length; w++) {
      if (typeof words[w] == "string") {
        if (words[w] === "Z") {
          for (z = 0; z < 8 - words.length + 1; z++) {
            parts[w + z] = 0;
          }
          offset = z - 1;
        } else {
          parts[w + offset] = _htons(parseInt(words[w], 16));
        }
      } else {
        parts[w + offset] = words[w];
      }
    }
    return [parts[1] << 16 | parts[0], parts[3] << 16 | parts[2], parts[5] << 16 | parts[4], parts[7] << 16 | parts[6]];
  };
  var zeroMemory = (ptr, size) => HEAPU8.fill(0, ptr, ptr + size);
  var writeSockaddr = (sa, family, addr, port, addrlen) => {
    switch (family) {
      case 2:
        addr = inetPton4(addr);
        zeroMemory(sa, 16);
        if (addrlen) {
          HEAP32[addrlen >> 2] = 16;
        }
        HEAP16[sa >> 1] = family;
        HEAP32[sa + 4 >> 2] = addr;
        HEAP16[sa + 2 >> 1] = _htons(port);
        break;
      case 10:
        addr = inetPton6(addr);
        zeroMemory(sa, 28);
        if (addrlen) {
          HEAP32[addrlen >> 2] = 28;
        }
        HEAP32[sa >> 2] = family;
        HEAP32[sa + 8 >> 2] = addr[0];
        HEAP32[sa + 12 >> 2] = addr[1];
        HEAP32[sa + 16 >> 2] = addr[2];
        HEAP32[sa + 20 >> 2] = addr[3];
        HEAP16[sa + 2 >> 1] = _htons(port);
        break;
      default:
        return 5;
    }
    return 0;
  };
  var DNS = { address_map: { id: 1, addrs: {}, names: {} }, lookup_name(name) {
    var res = inetPton4(name);
    if (res !== null) {
      return name;
    }
    res = inetPton6(name);
    if (res !== null) {
      return name;
    }
    var addr;
    if (DNS.address_map.addrs[name]) {
      addr = DNS.address_map.addrs[name];
    } else {
      var id = DNS.address_map.id++;
      addr = "172.29." + (id & 255) + "." + (id & 65280);
      DNS.address_map.names[addr] = name;
      DNS.address_map.addrs[name] = addr;
    }
    return addr;
  }, lookup_addr(addr) {
    if (DNS.address_map.names[addr]) {
      return DNS.address_map.names[addr];
    }
    return null;
  } };
  function ___syscall_accept4(fd, addr, addrlen, flags, d1, d2) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(3, 0, 1, fd, addr, addrlen, flags, d1, d2);
    try {
      var sock = getSocketFromFD(fd);
      var newsock = sock.sock_ops.accept(sock);
      if (addr) {
        var errno = writeSockaddr(addr, newsock.family, DNS.lookup_name(newsock.daddr), newsock.dport, addrlen);
      }
      return newsock.stream.fd;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  var inetNtop4 = (addr) => (addr & 255) + "." + (addr >> 8 & 255) + "." + (addr >> 16 & 255) + "." + (addr >> 24 & 255);
  var inetNtop6 = (ints) => {
    var str = "";
    var word = 0;
    var longest = 0;
    var lastzero = 0;
    var zstart = 0;
    var len = 0;
    var i = 0;
    var parts = [ints[0] & 65535, ints[0] >> 16, ints[1] & 65535, ints[1] >> 16, ints[2] & 65535, ints[2] >> 16, ints[3] & 65535, ints[3] >> 16];
    var hasipv4 = true;
    var v4part = "";
    for (i = 0; i < 5; i++) {
      if (parts[i] !== 0) {
        hasipv4 = false;
        break;
      }
    }
    if (hasipv4) {
      v4part = inetNtop4(parts[6] | parts[7] << 16);
      if (parts[5] === -1) {
        str = "::ffff:";
        str += v4part;
        return str;
      }
      if (parts[5] === 0) {
        str = "::";
        if (v4part === "0.0.0.0")
          v4part = "";
        if (v4part === "0.0.0.1")
          v4part = "1";
        str += v4part;
        return str;
      }
    }
    for (word = 0; word < 8; word++) {
      if (parts[word] === 0) {
        if (word - lastzero > 1) {
          len = 0;
        }
        lastzero = word;
        len++;
      }
      if (len > longest) {
        longest = len;
        zstart = word - longest + 1;
      }
    }
    for (word = 0; word < 8; word++) {
      if (longest > 1) {
        if (parts[word] === 0 && word >= zstart && word < zstart + longest) {
          if (word === zstart) {
            str += ":";
            if (zstart === 0)
              str += ":";
          }
          continue;
        }
      }
      str += Number(_ntohs(parts[word] & 65535)).toString(16);
      str += word < 7 ? ":" : "";
    }
    return str;
  };
  var readSockaddr = (sa, salen) => {
    var family = HEAP16[sa >> 1];
    var port = _ntohs(HEAPU16[sa + 2 >> 1]);
    var addr;
    switch (family) {
      case 2:
        if (salen !== 16) {
          return { errno: 28 };
        }
        addr = HEAP32[sa + 4 >> 2];
        addr = inetNtop4(addr);
        break;
      case 10:
        if (salen !== 28) {
          return { errno: 28 };
        }
        addr = [HEAP32[sa + 8 >> 2], HEAP32[sa + 12 >> 2], HEAP32[sa + 16 >> 2], HEAP32[sa + 20 >> 2]];
        addr = inetNtop6(addr);
        break;
      default:
        return { errno: 5 };
    }
    return { family, addr, port };
  };
  var getSocketAddress = (addrp, addrlen) => {
    var info = readSockaddr(addrp, addrlen);
    if (info.errno)
      throw new FS.ErrnoError(info.errno);
    info.addr = DNS.lookup_addr(info.addr) || info.addr;
    return info;
  };
  function ___syscall_bind(fd, addr, addrlen, d1, d2, d3) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(4, 0, 1, fd, addr, addrlen, d1, d2, d3);
    try {
      var sock = getSocketFromFD(fd);
      var info = getSocketAddress(addr, addrlen);
      sock.sock_ops.bind(sock, info.addr, info.port);
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  function ___syscall_connect(fd, addr, addrlen, d1, d2, d3) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(5, 0, 1, fd, addr, addrlen, d1, d2, d3);
    try {
      var sock = getSocketFromFD(fd);
      var info = getSocketAddress(addr, addrlen);
      sock.sock_ops.connect(sock, info.addr, info.port);
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  var syscallGetVarargI = () => {
    var ret = HEAP32[+SYSCALLS.varargs >> 2];
    SYSCALLS.varargs += 4;
    return ret;
  };
  var syscallGetVarargP = syscallGetVarargI;
  var SYSCALLS = { calculateAt(dirfd, path, allowEmpty) {
    if (PATH.isAbs(path)) {
      return path;
    }
    var dir;
    if (dirfd === -100) {
      dir = FS.cwd();
    } else {
      var dirstream = SYSCALLS.getStreamFromFD(dirfd);
      dir = dirstream.path;
    }
    if (path.length == 0) {
      if (!allowEmpty) {
        throw new FS.ErrnoError(44);
      }
      return dir;
    }
    return dir + "/" + path;
  }, writeStat(buf, stat) {
    HEAPU32[buf >> 2] = stat.dev;
    HEAPU32[buf + 4 >> 2] = stat.mode;
    HEAPU32[buf + 8 >> 2] = stat.nlink;
    HEAPU32[buf + 12 >> 2] = stat.uid;
    HEAPU32[buf + 16 >> 2] = stat.gid;
    HEAPU32[buf + 20 >> 2] = stat.rdev;
    HEAP64[buf + 24 >> 3] = BigInt(stat.size);
    HEAP32[buf + 32 >> 2] = 4096;
    HEAP32[buf + 36 >> 2] = stat.blocks;
    var atime = stat.atime.getTime();
    var mtime = stat.mtime.getTime();
    var ctime = stat.ctime.getTime();
    HEAP64[buf + 40 >> 3] = BigInt(Math.floor(atime / 1e3));
    HEAPU32[buf + 48 >> 2] = atime % 1e3 * 1e3 * 1e3;
    HEAP64[buf + 56 >> 3] = BigInt(Math.floor(mtime / 1e3));
    HEAPU32[buf + 64 >> 2] = mtime % 1e3 * 1e3 * 1e3;
    HEAP64[buf + 72 >> 3] = BigInt(Math.floor(ctime / 1e3));
    HEAPU32[buf + 80 >> 2] = ctime % 1e3 * 1e3 * 1e3;
    HEAP64[buf + 88 >> 3] = BigInt(stat.ino);
    return 0;
  }, writeStatFs(buf, stats) {
    HEAPU32[buf + 4 >> 2] = stats.bsize;
    HEAPU32[buf + 60 >> 2] = stats.bsize;
    HEAP64[buf + 8 >> 3] = BigInt(stats.blocks);
    HEAP64[buf + 16 >> 3] = BigInt(stats.bfree);
    HEAP64[buf + 24 >> 3] = BigInt(stats.bavail);
    HEAP64[buf + 32 >> 3] = BigInt(stats.files);
    HEAP64[buf + 40 >> 3] = BigInt(stats.ffree);
    HEAPU32[buf + 48 >> 2] = stats.fsid;
    HEAPU32[buf + 64 >> 2] = stats.flags;
    HEAPU32[buf + 56 >> 2] = stats.namelen;
  }, doMsync(addr, stream, len, flags, offset) {
    if (!FS.isFile(stream.node.mode)) {
      throw new FS.ErrnoError(43);
    }
    if (flags & 2) {
      return 0;
    }
    var buffer = HEAPU8.slice(addr, addr + len);
    FS.msync(stream, buffer, offset, len, flags);
  }, getStreamFromFD(fd) {
    var stream = FS.getStreamChecked(fd);
    return stream;
  }, varargs: void 0, getStr(ptr) {
    var ret = UTF8ToString(ptr);
    return ret;
  } };
  function ___syscall_fcntl64(fd, cmd, varargs) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(6, 0, 1, fd, cmd, varargs);
    SYSCALLS.varargs = varargs;
    try {
      var stream = SYSCALLS.getStreamFromFD(fd);
      switch (cmd) {
        case 0: {
          var arg = syscallGetVarargI();
          if (arg < 0) {
            return -28;
          }
          while (FS.streams[arg]) {
            arg++;
          }
          var newStream;
          newStream = FS.dupStream(stream, arg);
          return newStream.fd;
        }
        case 1:
        case 2:
          return 0;
        case 3:
          return stream.flags;
        case 4: {
          var arg = syscallGetVarargI();
          stream.flags |= arg;
          return 0;
        }
        case 12: {
          var arg = syscallGetVarargP();
          var offset = 0;
          HEAP16[arg + offset >> 1] = 2;
          return 0;
        }
        case 13:
        case 14:
          return 0;
      }
      return -28;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  function ___syscall_ioctl(fd, op, varargs) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(7, 0, 1, fd, op, varargs);
    SYSCALLS.varargs = varargs;
    try {
      var stream = SYSCALLS.getStreamFromFD(fd);
      switch (op) {
        case 21509: {
          if (!stream.tty)
            return -59;
          return 0;
        }
        case 21505: {
          if (!stream.tty)
            return -59;
          if (stream.tty.ops.ioctl_tcgets) {
            var termios = stream.tty.ops.ioctl_tcgets(stream);
            var argp = syscallGetVarargP();
            HEAP32[argp >> 2] = termios.c_iflag || 0;
            HEAP32[argp + 4 >> 2] = termios.c_oflag || 0;
            HEAP32[argp + 8 >> 2] = termios.c_cflag || 0;
            HEAP32[argp + 12 >> 2] = termios.c_lflag || 0;
            for (var i = 0; i < 32; i++) {
              HEAP8[argp + i + 17] = termios.c_cc[i] || 0;
            }
            return 0;
          }
          return 0;
        }
        case 21510:
        case 21511:
        case 21512: {
          if (!stream.tty)
            return -59;
          return 0;
        }
        case 21506:
        case 21507:
        case 21508: {
          if (!stream.tty)
            return -59;
          if (stream.tty.ops.ioctl_tcsets) {
            var argp = syscallGetVarargP();
            var c_iflag = HEAP32[argp >> 2];
            var c_oflag = HEAP32[argp + 4 >> 2];
            var c_cflag = HEAP32[argp + 8 >> 2];
            var c_lflag = HEAP32[argp + 12 >> 2];
            var c_cc = [];
            for (var i = 0; i < 32; i++) {
              c_cc.push(HEAP8[argp + i + 17]);
            }
            return stream.tty.ops.ioctl_tcsets(stream.tty, op, { c_iflag, c_oflag, c_cflag, c_lflag, c_cc });
          }
          return 0;
        }
        case 21519: {
          if (!stream.tty)
            return -59;
          var argp = syscallGetVarargP();
          HEAP32[argp >> 2] = 0;
          return 0;
        }
        case 21520: {
          if (!stream.tty)
            return -59;
          return -28;
        }
        case 21537:
        case 21531: {
          var argp = syscallGetVarargP();
          return FS.ioctl(stream, op, argp);
        }
        case 21523: {
          if (!stream.tty)
            return -59;
          if (stream.tty.ops.ioctl_tiocgwinsz) {
            var winsize = stream.tty.ops.ioctl_tiocgwinsz(stream.tty);
            var argp = syscallGetVarargP();
            HEAP16[argp >> 1] = winsize[0];
            HEAP16[argp + 2 >> 1] = winsize[1];
          }
          return 0;
        }
        case 21524: {
          if (!stream.tty)
            return -59;
          return 0;
        }
        case 21515: {
          if (!stream.tty)
            return -59;
          return 0;
        }
        default:
          return -28;
      }
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  function ___syscall_listen(fd, backlog) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(8, 0, 1, fd, backlog);
    try {
      var sock = getSocketFromFD(fd);
      sock.sock_ops.listen(sock, backlog);
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  function ___syscall_openat(dirfd, path, flags, varargs) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(9, 0, 1, dirfd, path, flags, varargs);
    SYSCALLS.varargs = varargs;
    try {
      path = SYSCALLS.getStr(path);
      path = SYSCALLS.calculateAt(dirfd, path);
      var mode = varargs ? syscallGetVarargI() : 0;
      return FS.open(path, flags, mode).fd;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  var PIPEFS = { BUCKET_BUFFER_SIZE: 8192, mount(mount) {
    return FS.createNode(null, "/", 16384 | 511, 0);
  }, createPipe() {
    var pipe = { buckets: [], refcnt: 2, timestamp: /* @__PURE__ */ new Date(), readableHandlers: [], registerReadableHandler: (callback) => {
      callback.registerCleanupFunc(() => {
        const i = pipe.readableHandlers.indexOf(callback);
        if (i !== -1)
          pipe.readableHandlers.splice(i, 1);
      });
      pipe.readableHandlers.push(callback);
    }, notifyReadableHandlers: () => {
      while (pipe.readableHandlers.length > 0) {
        const cb = pipe.readableHandlers.shift();
        if (cb)
          cb(64 | 1);
      }
      pipe.readableHandlers = [];
    } };
    pipe.buckets.push({ buffer: new Uint8Array(PIPEFS.BUCKET_BUFFER_SIZE), offset: 0, roffset: 0 });
    var rName = PIPEFS.nextname();
    var wName = PIPEFS.nextname();
    var rNode = FS.createNode(PIPEFS.root, rName, 4096, 0);
    var wNode = FS.createNode(PIPEFS.root, wName, 4096, 0);
    rNode.pipe = pipe;
    wNode.pipe = pipe;
    var readableStream = FS.createStream({ path: rName, node: rNode, flags: 0, seekable: false, stream_ops: PIPEFS.stream_ops });
    rNode.stream = readableStream;
    var writableStream = FS.createStream({ path: wName, node: wNode, flags: 1, seekable: false, stream_ops: PIPEFS.stream_ops });
    wNode.stream = writableStream;
    return { readable_fd: readableStream.fd, writable_fd: writableStream.fd };
  }, stream_ops: { getattr(stream) {
    var node = stream.node;
    var timestamp = node.pipe.timestamp;
    return { dev: 14, ino: node.id, mode: 4480, nlink: 1, uid: 0, gid: 0, rdev: 0, size: 0, atime: timestamp, mtime: timestamp, ctime: timestamp, blksize: 4096, blocks: 0 };
  }, poll(stream, timeout, notifyCallback) {
    var pipe = stream.node.pipe;
    if ((stream.flags & 2097155) === 1) {
      return 256 | 4;
    }
    for (var bucket of pipe.buckets) {
      if (bucket.offset - bucket.roffset > 0) {
        return 64 | 1;
      }
    }
    if (notifyCallback)
      pipe.registerReadableHandler(notifyCallback);
    return 0;
  }, dup(stream) {
    stream.node.pipe.refcnt++;
  }, ioctl(stream, request, varargs) {
    return 28;
  }, fsync(stream) {
    return 28;
  }, read(stream, buffer, offset, length, position) {
    var pipe = stream.node.pipe;
    var currentLength = 0;
    for (var bucket of pipe.buckets) {
      currentLength += bucket.offset - bucket.roffset;
    }
    var data = buffer.subarray(offset, offset + length);
    if (length <= 0) {
      return 0;
    }
    if (currentLength == 0) {
      throw new FS.ErrnoError(6);
    }
    var toRead = Math.min(currentLength, length);
    var totalRead = toRead;
    var toRemove = 0;
    for (var bucket of pipe.buckets) {
      var bucketSize = bucket.offset - bucket.roffset;
      if (toRead <= bucketSize) {
        var tmpSlice = bucket.buffer.subarray(bucket.roffset, bucket.offset);
        if (toRead < bucketSize) {
          tmpSlice = tmpSlice.subarray(0, toRead);
          bucket.roffset += toRead;
        } else {
          toRemove++;
        }
        data.set(tmpSlice);
        break;
      } else {
        var tmpSlice = bucket.buffer.subarray(bucket.roffset, bucket.offset);
        data.set(tmpSlice);
        data = data.subarray(tmpSlice.byteLength);
        toRead -= tmpSlice.byteLength;
        toRemove++;
      }
    }
    if (toRemove && toRemove == pipe.buckets.length) {
      toRemove--;
      pipe.buckets[toRemove].offset = 0;
      pipe.buckets[toRemove].roffset = 0;
    }
    pipe.buckets.splice(0, toRemove);
    return totalRead;
  }, write(stream, buffer, offset, length, position) {
    var pipe = stream.node.pipe;
    var data = buffer.subarray(offset, offset + length);
    var dataLen = data.byteLength;
    if (dataLen <= 0) {
      return 0;
    }
    var currBucket = null;
    if (pipe.buckets.length == 0) {
      currBucket = { buffer: new Uint8Array(PIPEFS.BUCKET_BUFFER_SIZE), offset: 0, roffset: 0 };
      pipe.buckets.push(currBucket);
    } else {
      currBucket = pipe.buckets[pipe.buckets.length - 1];
    }
    var freeBytesInCurrBuffer = PIPEFS.BUCKET_BUFFER_SIZE - currBucket.offset;
    if (freeBytesInCurrBuffer >= dataLen) {
      currBucket.buffer.set(data, currBucket.offset);
      currBucket.offset += dataLen;
      pipe.notifyReadableHandlers();
      return dataLen;
    } else if (freeBytesInCurrBuffer > 0) {
      currBucket.buffer.set(data.subarray(0, freeBytesInCurrBuffer), currBucket.offset);
      currBucket.offset += freeBytesInCurrBuffer;
      data = data.subarray(freeBytesInCurrBuffer, data.byteLength);
    }
    var numBuckets = data.byteLength / PIPEFS.BUCKET_BUFFER_SIZE | 0;
    var remElements = data.byteLength % PIPEFS.BUCKET_BUFFER_SIZE;
    for (var i = 0; i < numBuckets; i++) {
      var newBucket = { buffer: new Uint8Array(PIPEFS.BUCKET_BUFFER_SIZE), offset: PIPEFS.BUCKET_BUFFER_SIZE, roffset: 0 };
      pipe.buckets.push(newBucket);
      newBucket.buffer.set(data.subarray(0, PIPEFS.BUCKET_BUFFER_SIZE));
      data = data.subarray(PIPEFS.BUCKET_BUFFER_SIZE, data.byteLength);
    }
    if (remElements > 0) {
      var newBucket = { buffer: new Uint8Array(PIPEFS.BUCKET_BUFFER_SIZE), offset: data.byteLength, roffset: 0 };
      pipe.buckets.push(newBucket);
      newBucket.buffer.set(data);
    }
    pipe.notifyReadableHandlers();
    return dataLen;
  }, close(stream) {
    var pipe = stream.node.pipe;
    pipe.refcnt--;
    if (pipe.refcnt === 0) {
      pipe.buckets = null;
    }
  } }, nextname() {
    if (!PIPEFS.nextname.current) {
      PIPEFS.nextname.current = 0;
    }
    return "pipe[" + PIPEFS.nextname.current++ + "]";
  } };
  function ___syscall_pipe(fdPtr) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(10, 0, 1, fdPtr);
    try {
      if (fdPtr == 0) {
        throw new FS.ErrnoError(21);
      }
      var res = PIPEFS.createPipe();
      HEAP32[fdPtr >> 2] = res.readable_fd;
      HEAP32[fdPtr + 4 >> 2] = res.writable_fd;
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  var ___syscall_poll = function(fds, nfds, timeout) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(11, 0, 2, fds, nfds, timeout);
    let innerFunc = () => {
      try {
        let asyncPollComplete = function(count2) {
          if (notifyDone) {
            return;
          }
          notifyDone = true;
          cleanupFuncs.forEach((cb) => cb());
          resolve(count2);
        }, makeNotifyCallback = function(stream2, pollfd2) {
          var cb = (flags2) => {
            if (notifyDone) {
              return;
            }
            var events2 = HEAP16[pollfd2 + 4 >> 1];
            flags2 &= events2 | 8 | 16;
            HEAP16[pollfd2 + 6 >> 1] = flags2;
            asyncPollComplete(1);
          };
          cb.registerCleanupFunc = (f) => {
            if (f)
              cleanupFuncs.push(f);
          };
          return cb;
        };
        const isAsyncContext = PThread.currentProxiedOperationCallerThread;
        var resolve;
        var promise = new Promise((resolve_) => {
          resolve = resolve_;
        });
        var cleanupFuncs = [];
        var notifyDone = false;
        if (isAsyncContext) {
          if (timeout > 0) {
            var t = setTimeout(() => {
              asyncPollComplete(0);
            }, timeout);
            cleanupFuncs.push(() => clearTimeout(t));
          }
        }
        var count = 0;
        for (var i = 0; i < nfds; i++) {
          var pollfd = fds + 8 * i;
          var fd = HEAP32[pollfd >> 2];
          var events = HEAP16[pollfd + 4 >> 1];
          var flags = 32;
          var stream = FS.getStream(fd);
          if (stream) {
            if (stream.stream_ops.poll) {
              if (isAsyncContext && timeout) {
                flags = stream.stream_ops.poll(stream, timeout, makeNotifyCallback(stream, pollfd));
              } else
                flags = stream.stream_ops.poll(stream, -1);
            } else {
              flags = 5;
            }
          }
          flags &= events | 8 | 16;
          if (flags)
            count++;
          HEAP16[pollfd + 6 >> 1] = flags;
        }
        if (isAsyncContext) {
          if (count || !timeout) {
            asyncPollComplete(count);
          }
          return promise;
        }
        return count;
      } catch (e) {
        if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
          throw e;
        return -e.errno;
      }
    };
    return Asyncify.handleAsync(innerFunc);
  };
  ___syscall_poll.isAsync = true;
  function ___syscall_recvfrom(fd, buf, len, flags, addr, addrlen) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(12, 0, 1, fd, buf, len, flags, addr, addrlen);
    try {
      var sock = getSocketFromFD(fd);
      var msg = sock.sock_ops.recvmsg(sock, len);
      if (!msg)
        return 0;
      if (addr) {
        var errno = writeSockaddr(addr, sock.family, DNS.lookup_name(msg.addr), msg.port, addrlen);
      }
      HEAPU8.set(msg.buffer, buf);
      return msg.buffer.byteLength;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  function ___syscall_sendto(fd, message, length, flags, addr, addr_len) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(13, 0, 1, fd, message, length, flags, addr, addr_len);
    try {
      var sock = getSocketFromFD(fd);
      if (!addr) {
        return FS.write(sock.stream, HEAP8, message, length);
      }
      var dest = getSocketAddress(addr, addr_len);
      return sock.sock_ops.sendmsg(sock, HEAP8, message, length, dest.addr, dest.port);
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  function ___syscall_socket(domain, type, protocol) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(14, 0, 1, domain, type, protocol);
    try {
      var sock = SOCKFS.createSocket(domain, type, protocol);
      return sock.stream.fd;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return -e.errno;
    }
  }
  var __abort_js = () => abort("");
  var AsciiToString = (ptr) => {
    var str = "";
    while (1) {
      var ch = HEAPU8[ptr++];
      if (!ch)
        return str;
      str += String.fromCharCode(ch);
    }
  };
  var awaitingDependencies = {};
  var registeredTypes = {};
  var typeDependencies = {};
  var BindingError = class BindingError extends Error {
    constructor(message) {
      super(message);
      this.name = "BindingError";
    }
  };
  var throwBindingError = (message) => {
    throw new BindingError(message);
  };
  function sharedRegisterType(rawType, registeredInstance, options = {}) {
    var name = registeredInstance.name;
    if (!rawType) {
      throwBindingError(`type "${name}" must have a positive integer typeid pointer`);
    }
    if (registeredTypes.hasOwnProperty(rawType)) {
      if (options.ignoreDuplicateRegistrations) {
        return;
      } else {
        throwBindingError(`Cannot register type '${name}' twice`);
      }
    }
    registeredTypes[rawType] = registeredInstance;
    delete typeDependencies[rawType];
    if (awaitingDependencies.hasOwnProperty(rawType)) {
      var callbacks = awaitingDependencies[rawType];
      delete awaitingDependencies[rawType];
      callbacks.forEach((cb) => cb());
    }
  }
  function registerType(rawType, registeredInstance, options = {}) {
    return sharedRegisterType(rawType, registeredInstance, options);
  }
  var integerReadValueFromPointer = (name, width, signed) => {
    switch (width) {
      case 1:
        return signed ? (pointer) => HEAP8[pointer] : (pointer) => HEAPU8[pointer];
      case 2:
        return signed ? (pointer) => HEAP16[pointer >> 1] : (pointer) => HEAPU16[pointer >> 1];
      case 4:
        return signed ? (pointer) => HEAP32[pointer >> 2] : (pointer) => HEAPU32[pointer >> 2];
      case 8:
        return signed ? (pointer) => HEAP64[pointer >> 3] : (pointer) => HEAPU64[pointer >> 3];
      default:
        throw new TypeError(`invalid integer width (${width}): ${name}`);
    }
  };
  var __embind_register_bigint = (primitiveType, name, size, minRange, maxRange) => {
    name = AsciiToString(name);
    const isUnsignedType = minRange === 0n;
    let fromWireType = (value) => value;
    if (isUnsignedType) {
      const bitSize = size * 8;
      fromWireType = (value) => BigInt.asUintN(bitSize, value);
      maxRange = fromWireType(maxRange);
    }
    registerType(primitiveType, { name, fromWireType, toWireType: (destructors, value) => {
      if (typeof value == "number") {
        value = BigInt(value);
      }
      return value;
    }, readValueFromPointer: integerReadValueFromPointer(name, size, !isUnsignedType), destructorFunction: null });
  };
  var __embind_register_bool = (rawType, name, trueValue, falseValue) => {
    name = AsciiToString(name);
    registerType(rawType, { name, fromWireType: function(wt) {
      return !!wt;
    }, toWireType: function(destructors, o) {
      return o ? trueValue : falseValue;
    }, readValueFromPointer: function(pointer) {
      return this.fromWireType(HEAPU8[pointer]);
    }, destructorFunction: null });
  };
  var emval_freelist = [];
  var emval_handles = [0, 1, , 1, null, 1, true, 1, false, 1];
  var __emval_decref = (handle) => {
    if (handle > 9 && 0 === --emval_handles[handle + 1]) {
      emval_handles[handle] = void 0;
      emval_freelist.push(handle);
    }
  };
  var Emval = { toValue: (handle) => {
    if (!handle) {
      throwBindingError(`Cannot use deleted val. handle = ${handle}`);
    }
    return emval_handles[handle];
  }, toHandle: (value) => {
    switch (value) {
      case void 0:
        return 2;
      case null:
        return 4;
      case true:
        return 6;
      case false:
        return 8;
      default: {
        const handle = emval_freelist.pop() || emval_handles.length;
        emval_handles[handle] = value;
        emval_handles[handle + 1] = 1;
        return handle;
      }
    }
  } };
  function readPointer(pointer) {
    return this.fromWireType(HEAPU32[pointer >> 2]);
  }
  var EmValType = { name: "emscripten::val", fromWireType: (handle) => {
    var rv = Emval.toValue(handle);
    __emval_decref(handle);
    return rv;
  }, toWireType: (destructors, value) => Emval.toHandle(value), readValueFromPointer: readPointer, destructorFunction: null };
  var __embind_register_emval = (rawType) => registerType(rawType, EmValType);
  var floatReadValueFromPointer = (name, width) => {
    switch (width) {
      case 4:
        return function(pointer) {
          return this.fromWireType(HEAPF32[pointer >> 2]);
        };
      case 8:
        return function(pointer) {
          return this.fromWireType(HEAPF64[pointer >> 3]);
        };
      default:
        throw new TypeError(`invalid float width (${width}): ${name}`);
    }
  };
  var __embind_register_float = (rawType, name, size) => {
    name = AsciiToString(name);
    registerType(rawType, { name, fromWireType: (value) => value, toWireType: (destructors, value) => value, readValueFromPointer: floatReadValueFromPointer(name, size), destructorFunction: null });
  };
  var __embind_register_integer = (primitiveType, name, size, minRange, maxRange) => {
    name = AsciiToString(name);
    const isUnsignedType = minRange === 0;
    let fromWireType = (value) => value;
    if (isUnsignedType) {
      var bitshift = 32 - 8 * size;
      fromWireType = (value) => value << bitshift >>> bitshift;
      maxRange = fromWireType(maxRange);
    }
    registerType(primitiveType, { name, fromWireType, toWireType: (destructors, value) => value, readValueFromPointer: integerReadValueFromPointer(name, size, minRange !== 0), destructorFunction: null });
  };
  var __embind_register_memory_view = (rawType, dataTypeIndex, name) => {
    var typeMapping = [Int8Array, Uint8Array, Int16Array, Uint16Array, Int32Array, Uint32Array, Float32Array, Float64Array, BigInt64Array, BigUint64Array];
    var TA = typeMapping[dataTypeIndex];
    function decodeMemoryView(handle) {
      var size = HEAPU32[handle >> 2];
      var data = HEAPU32[handle + 4 >> 2];
      return new TA(HEAP8.buffer, data, size);
    }
    name = AsciiToString(name);
    registerType(rawType, { name, fromWireType: decodeMemoryView, readValueFromPointer: decodeMemoryView }, { ignoreDuplicateRegistrations: true });
  };
  var stringToUTF8 = (str, outPtr, maxBytesToWrite) => stringToUTF8Array(str, HEAPU8, outPtr, maxBytesToWrite);
  var __embind_register_std_string = (rawType, name) => {
    name = AsciiToString(name);
    var stdStringIsUTF8 = true;
    registerType(rawType, { name, fromWireType(value) {
      var length = HEAPU32[value >> 2];
      var payload = value + 4;
      var str;
      if (stdStringIsUTF8) {
        str = UTF8ToString(payload, length, true);
      } else {
        str = "";
        for (var i = 0; i < length; ++i) {
          str += String.fromCharCode(HEAPU8[payload + i]);
        }
      }
      _free(value);
      return str;
    }, toWireType(destructors, value) {
      if (value instanceof ArrayBuffer) {
        value = new Uint8Array(value);
      }
      var length;
      var valueIsOfTypeString = typeof value == "string";
      if (!(valueIsOfTypeString || ArrayBuffer.isView(value) && value.BYTES_PER_ELEMENT == 1)) {
        throwBindingError("Cannot pass non-string to std::string");
      }
      if (stdStringIsUTF8 && valueIsOfTypeString) {
        length = lengthBytesUTF8(value);
      } else {
        length = value.length;
      }
      var base = _malloc(4 + length + 1);
      var ptr = base + 4;
      HEAPU32[base >> 2] = length;
      if (valueIsOfTypeString) {
        if (stdStringIsUTF8) {
          stringToUTF8(value, ptr, length + 1);
        } else {
          for (var i = 0; i < length; ++i) {
            var charCode = value.charCodeAt(i);
            if (charCode > 255) {
              _free(base);
              throwBindingError("String has UTF-16 code units that do not fit in 8 bits");
            }
            HEAPU8[ptr + i] = charCode;
          }
        }
      } else {
        HEAPU8.set(value, ptr);
      }
      if (destructors !== null) {
        destructors.push(_free, base);
      }
      return base;
    }, readValueFromPointer: readPointer, destructorFunction(ptr) {
      _free(ptr);
    } });
  };
  var UTF16Decoder = globalThis.TextDecoder ? new TextDecoder("utf-16le") : void 0;
  var UTF16ToString = (ptr, maxBytesToRead, ignoreNul) => {
    var idx = ptr >> 1;
    var endIdx = findStringEnd(HEAPU16, idx, maxBytesToRead / 2, ignoreNul);
    if (endIdx - idx > 16 && UTF16Decoder)
      return UTF16Decoder.decode(HEAPU16.slice(idx, endIdx));
    var str = "";
    for (var i = idx; i < endIdx; ++i) {
      var codeUnit = HEAPU16[i];
      str += String.fromCharCode(codeUnit);
    }
    return str;
  };
  var stringToUTF16 = (str, outPtr, maxBytesToWrite) => {
    maxBytesToWrite ??= 2147483647;
    if (maxBytesToWrite < 2)
      return 0;
    maxBytesToWrite -= 2;
    var startPtr = outPtr;
    var numCharsToWrite = maxBytesToWrite < str.length * 2 ? maxBytesToWrite / 2 : str.length;
    for (var i = 0; i < numCharsToWrite; ++i) {
      var codeUnit = str.charCodeAt(i);
      HEAP16[outPtr >> 1] = codeUnit;
      outPtr += 2;
    }
    HEAP16[outPtr >> 1] = 0;
    return outPtr - startPtr;
  };
  var lengthBytesUTF16 = (str) => str.length * 2;
  var UTF32ToString = (ptr, maxBytesToRead, ignoreNul) => {
    var str = "";
    var startIdx = ptr >> 2;
    for (var i = 0; !(i >= maxBytesToRead / 4); i++) {
      var utf32 = HEAPU32[startIdx + i];
      if (!utf32 && !ignoreNul)
        break;
      str += String.fromCodePoint(utf32);
    }
    return str;
  };
  var stringToUTF32 = (str, outPtr, maxBytesToWrite) => {
    maxBytesToWrite ??= 2147483647;
    if (maxBytesToWrite < 4)
      return 0;
    var startPtr = outPtr;
    var endPtr = startPtr + maxBytesToWrite - 4;
    for (var i = 0; i < str.length; ++i) {
      var codePoint = str.codePointAt(i);
      if (codePoint > 65535) {
        i++;
      }
      HEAP32[outPtr >> 2] = codePoint;
      outPtr += 4;
      if (outPtr + 4 > endPtr)
        break;
    }
    HEAP32[outPtr >> 2] = 0;
    return outPtr - startPtr;
  };
  var lengthBytesUTF32 = (str) => {
    var len = 0;
    for (var i = 0; i < str.length; ++i) {
      var codePoint = str.codePointAt(i);
      if (codePoint > 65535) {
        i++;
      }
      len += 4;
    }
    return len;
  };
  var __embind_register_std_wstring = (rawType, charSize, name) => {
    name = AsciiToString(name);
    var decodeString, encodeString, lengthBytesUTF;
    if (charSize === 2) {
      decodeString = UTF16ToString;
      encodeString = stringToUTF16;
      lengthBytesUTF = lengthBytesUTF16;
    } else {
      decodeString = UTF32ToString;
      encodeString = stringToUTF32;
      lengthBytesUTF = lengthBytesUTF32;
    }
    registerType(rawType, { name, fromWireType: (value) => {
      var length = HEAPU32[value >> 2];
      var str = decodeString(value + 4, length * charSize, true);
      _free(value);
      return str;
    }, toWireType: (destructors, value) => {
      if (!(typeof value == "string")) {
        throwBindingError(`Cannot pass non-string to C++ string type ${name}`);
      }
      var length = lengthBytesUTF(value);
      var ptr = _malloc(4 + length + charSize);
      HEAPU32[ptr >> 2] = length / charSize;
      encodeString(value, ptr + 4, length + charSize);
      if (destructors !== null) {
        destructors.push(_free, ptr);
      }
      return ptr;
    }, readValueFromPointer: readPointer, destructorFunction(ptr) {
      _free(ptr);
    } });
  };
  var __embind_register_void = (rawType, name) => {
    name = AsciiToString(name);
    registerType(rawType, { isVoid: true, name, fromWireType: () => void 0, toWireType: (destructors, o) => void 0 });
  };
  var __emscripten_init_main_thread_js = (tb) => {
    __emscripten_thread_init(tb, !ENVIRONMENT_IS_WORKER, 1, !ENVIRONMENT_IS_WEB, 65536, false);
    PThread.threadInitTLS();
  };
  var handleException = (e) => {
    if (e instanceof ExitStatus || e == "unwind") {
      return EXITSTATUS;
    }
    quit_(1, e);
  };
  var maybeExit = () => {
    if (runtimeExited) {
      return;
    }
    if (!keepRuntimeAlive()) {
      try {
        if (ENVIRONMENT_IS_PTHREAD) {
          if (_pthread_self())
            __emscripten_thread_exit(EXITSTATUS);
          return;
        }
        _exit(EXITSTATUS);
      } catch (e) {
        handleException(e);
      }
    }
  };
  var callUserCallback = (func) => {
    if (runtimeExited || ABORT) {
      return;
    }
    try {
      return func();
    } catch (e) {
      handleException(e);
    } finally {
      maybeExit();
    }
  };
  var waitAsyncPolyfilled = !Atomics.waitAsync || globalThis.navigator?.userAgent && Number((navigator.userAgent.match(/Chrom(e|ium)\/([0-9]+)\./) || [])[2]) < 91;
  var __emscripten_thread_mailbox_await = (pthread_ptr) => {
    if (!waitAsyncPolyfilled) {
      var wait = Atomics.waitAsync(HEAP32, pthread_ptr >> 2, pthread_ptr);
      wait.value.then(checkMailbox);
      var waitingAsync = pthread_ptr + 128;
      Atomics.store(HEAP32, waitingAsync >> 2, 1);
    }
  };
  var checkMailbox = () => callUserCallback(() => {
    var pthread_ptr = _pthread_self();
    if (pthread_ptr) {
      __emscripten_thread_mailbox_await(pthread_ptr);
      __emscripten_check_mailbox();
    }
  });
  var __emscripten_notify_mailbox_postmessage = (targetThread, currThreadId) => {
    if (targetThread == currThreadId) {
      setTimeout(checkMailbox);
    } else if (ENVIRONMENT_IS_PTHREAD) {
      postMessage({ targetThread, cmd: "checkMailbox" });
    } else {
      var worker = PThread.pthreads[targetThread];
      if (!worker) {
        return;
      }
      worker.postMessage({ cmd: "checkMailbox" });
    }
  };
  var proxiedJSCallArgs = [];
  var __emscripten_receive_on_main_thread_js = (funcIndex, emAsmAddr, callingThread, bufSize, args, ctx, ctxArgs) => {
    proxiedJSCallArgs.length = 0;
    var b = args >> 3;
    var end = args + bufSize >> 3;
    while (b < end) {
      var arg;
      if (HEAP64[b++]) {
        arg = HEAP64[b++];
      } else {
        arg = HEAPF64[b++];
      }
      proxiedJSCallArgs.push(arg);
    }
    var func = proxiedFunctionTable[funcIndex];
    PThread.currentProxiedOperationCallerThread = callingThread;
    var rtn = func(...proxiedJSCallArgs);
    PThread.currentProxiedOperationCallerThread = 0;
    if (ctx) {
      rtn.then((rtn2) => __emscripten_run_js_on_main_thread_done(ctx, ctxArgs, rtn2));
      return;
    }
    return rtn;
  };
  var __emscripten_thread_cleanup = (thread) => {
    if (!ENVIRONMENT_IS_PTHREAD)
      cleanupThread(thread);
    else
      postMessage({ cmd: "cleanupThread", thread });
  };
  var __emscripten_thread_set_strongref = (thread) => {
  };
  var runAndAbortIfError = (func) => {
    try {
      return func();
    } catch (e) {
      abort(e);
    }
  };
  var runtimeKeepalivePush = () => {
    runtimeKeepaliveCounter += 1;
  };
  var runtimeKeepalivePop = () => {
    runtimeKeepaliveCounter -= 1;
  };
  var Asyncify = { instrumentWasmImports(imports) {
    var importPattern = /^(invoke_.*|__asyncjs__.*)$/;
    for (let [x, original] of Object.entries(imports)) {
      if (typeof original == "function") {
        let isAsyncifyImport = original.isAsync || importPattern.test(x);
      }
    }
  }, instrumentFunction(original) {
    var wrapper = (...args) => {
      Asyncify.exportCallStack.push(original);
      try {
        return original(...args);
      } finally {
        if (!ABORT) {
          var top = Asyncify.exportCallStack.pop();
          Asyncify.maybeStopUnwind();
        }
      }
    };
    Asyncify.funcWrappers.set(original, wrapper);
    return wrapper;
  }, instrumentWasmExports(exports) {
    var ret = {};
    for (let [x, original] of Object.entries(exports)) {
      if (typeof original == "function") {
        var wrapper = Asyncify.instrumentFunction(original);
        ret[x] = wrapper;
      } else {
        ret[x] = original;
      }
    }
    return ret;
  }, State: { Normal: 0, Unwinding: 1, Rewinding: 2, Disabled: 3 }, state: 0, StackSize: 4096, currData: null, handleSleepReturnValue: 0, exportCallStack: [], callstackFuncToId: /* @__PURE__ */ new Map(), callStackIdToFunc: /* @__PURE__ */ new Map(), funcWrappers: /* @__PURE__ */ new Map(), callStackId: 0, asyncPromiseHandlers: null, sleepCallbacks: [], getCallStackId(func) {
    if (!Asyncify.callstackFuncToId.has(func)) {
      var id = Asyncify.callStackId++;
      Asyncify.callstackFuncToId.set(func, id);
      Asyncify.callStackIdToFunc.set(id, func);
    }
    return Asyncify.callstackFuncToId.get(func);
  }, maybeStopUnwind() {
    if (Asyncify.currData && Asyncify.state === Asyncify.State.Unwinding && Asyncify.exportCallStack.length === 0) {
      Asyncify.state = Asyncify.State.Normal;
      runtimeKeepalivePush();
      runAndAbortIfError(_asyncify_stop_unwind);
      if (typeof Fibers != "undefined") {
        Fibers.trampoline();
      }
    }
  }, whenDone() {
    return new Promise((resolve, reject) => {
      Asyncify.asyncPromiseHandlers = { resolve, reject };
    });
  }, allocateData() {
    var ptr = _malloc(12 + Asyncify.StackSize);
    Asyncify.setDataHeader(ptr, ptr + 12, Asyncify.StackSize);
    Asyncify.setDataRewindFunc(ptr);
    return ptr;
  }, setDataHeader(ptr, stack, stackSize) {
    HEAPU32[ptr >> 2] = stack;
    HEAPU32[ptr + 4 >> 2] = stack + stackSize;
  }, setDataRewindFunc(ptr) {
    var bottomOfCallStack = Asyncify.exportCallStack[0];
    var rewindId = Asyncify.getCallStackId(bottomOfCallStack);
    HEAP32[ptr + 8 >> 2] = rewindId;
  }, getDataRewindFunc(ptr) {
    var id = HEAP32[ptr + 8 >> 2];
    var func = Asyncify.callStackIdToFunc.get(id);
    return func;
  }, doRewind(ptr) {
    var original = Asyncify.getDataRewindFunc(ptr);
    var func = Asyncify.funcWrappers.get(original);
    runtimeKeepalivePop();
    return callUserCallback(func);
  }, handleSleep(startAsync) {
    if (ABORT)
      return;
    if (Asyncify.state === Asyncify.State.Normal) {
      var reachedCallback = false;
      var reachedAfterCallback = false;
      startAsync((handleSleepReturnValue = 0) => {
        if (ABORT)
          return;
        Asyncify.handleSleepReturnValue = handleSleepReturnValue;
        reachedCallback = true;
        if (!reachedAfterCallback) {
          return;
        }
        Asyncify.state = Asyncify.State.Rewinding;
        runAndAbortIfError(() => _asyncify_start_rewind(Asyncify.currData));
        if (typeof MainLoop != "undefined" && MainLoop.func) {
          MainLoop.resume();
        }
        var asyncWasmReturnValue, isError = false;
        try {
          asyncWasmReturnValue = Asyncify.doRewind(Asyncify.currData);
        } catch (err2) {
          asyncWasmReturnValue = err2;
          isError = true;
        }
        var handled = false;
        if (!Asyncify.currData) {
          var asyncPromiseHandlers = Asyncify.asyncPromiseHandlers;
          if (asyncPromiseHandlers) {
            Asyncify.asyncPromiseHandlers = null;
            (isError ? asyncPromiseHandlers.reject : asyncPromiseHandlers.resolve)(asyncWasmReturnValue);
            handled = true;
          }
        }
        if (isError && !handled) {
          throw asyncWasmReturnValue;
        }
      });
      reachedAfterCallback = true;
      if (!reachedCallback) {
        Asyncify.state = Asyncify.State.Unwinding;
        Asyncify.currData = Asyncify.allocateData();
        if (typeof MainLoop != "undefined" && MainLoop.func) {
          MainLoop.pause();
        }
        runAndAbortIfError(() => _asyncify_start_unwind(Asyncify.currData));
      }
    } else if (Asyncify.state === Asyncify.State.Rewinding) {
      Asyncify.state = Asyncify.State.Normal;
      runAndAbortIfError(_asyncify_stop_rewind);
      _free(Asyncify.currData);
      Asyncify.currData = null;
      Asyncify.sleepCallbacks.forEach(callUserCallback);
    } else {
      abort(`invalid state: ${Asyncify.state}`);
    }
    return Asyncify.handleSleepReturnValue;
  }, handleAsync: (startAsync) => Asyncify.handleSleep(async (wakeUp) => {
    wakeUp(await startAsync());
  }) };
  var __emval_await = function(promise) {
    let innerFunc = async () => {
      var value = await Emval.toValue(promise);
      return Emval.toHandle(value);
    };
    return Asyncify.handleAsync(innerFunc);
  };
  __emval_await.isAsync = true;
  var __emval_coro_make_promise = (resolveHandlePtr, rejectHandlePtr) => Emval.toHandle(new Promise((resolve, reject) => {
    HEAPU32[resolveHandlePtr >> 2] = Emval.toHandle(resolve);
    HEAPU32[rejectHandlePtr >> 2] = Emval.toHandle(reject);
  }));
  var __emval_coro_suspend = (promiseHandle, awaiterPtr) => {
    Emval.toValue(promiseHandle).then((result) => __emval_coro_resume(awaiterPtr, Emval.toHandle(result)), (error) => __emval_coro_reject(awaiterPtr, Emval.toHandle(error)));
  };
  var emval_methodCallers = [];
  var emval_addMethodCaller = (caller) => {
    var id = emval_methodCallers.length;
    emval_methodCallers.push(caller);
    return id;
  };
  var getTypeName = (type) => {
    var ptr = ___getTypeName(type);
    var rv = AsciiToString(ptr);
    _free(ptr);
    return rv;
  };
  var requireRegisteredType = (rawType, humanName) => {
    var impl = registeredTypes[rawType];
    if (void 0 === impl) {
      throwBindingError(`${humanName} has unknown type ${getTypeName(rawType)}`);
    }
    return impl;
  };
  var emval_lookupTypes = (argCount, argTypes) => {
    var a = new Array(argCount);
    for (var i = 0; i < argCount; ++i) {
      a[i] = requireRegisteredType(HEAPU32[argTypes + i * 4 >> 2], `parameter ${i}`);
    }
    return a;
  };
  var createNamedFunction = (name, func) => Object.defineProperty(func, "name", { value: name });
  var emval_returnValue = (toReturnWire, destructorsRef, handle) => {
    var destructors = [];
    var result = toReturnWire(destructors, handle);
    if (destructors.length) {
      HEAPU32[destructorsRef >> 2] = Emval.toHandle(destructors);
    }
    return result;
  };
  var emval_symbols = {};
  var getStringOrSymbol = (address) => {
    var symbol = emval_symbols[address];
    if (symbol === void 0) {
      return AsciiToString(address);
    }
    return symbol;
  };
  var __emval_create_invoker = (argCount, argTypesPtr, kind) => {
    var GenericWireTypeSize = 8;
    var [retType, ...argTypes] = emval_lookupTypes(argCount, argTypesPtr);
    var toReturnWire = retType.toWireType.bind(retType);
    var argFromPtr = argTypes.map((type) => type.readValueFromPointer.bind(type));
    argCount--;
    var captures = { toValue: Emval.toValue };
    var args = argFromPtr.map((argFromPtr2, i) => {
      var captureName = `argFromPtr${i}`;
      captures[captureName] = argFromPtr2;
      return `${captureName}(args${i ? "+" + i * GenericWireTypeSize : ""})`;
    });
    var functionBody;
    switch (kind) {
      case 0:
        functionBody = "toValue(handle)";
        break;
      case 2:
        functionBody = "new (toValue(handle))";
        break;
      case 3:
        functionBody = "";
        break;
      case 1:
        captures["getStringOrSymbol"] = getStringOrSymbol;
        functionBody = "toValue(handle)[getStringOrSymbol(methodName)]";
        break;
    }
    functionBody += `(${args})`;
    if (!retType.isVoid) {
      captures["toReturnWire"] = toReturnWire;
      captures["emval_returnValue"] = emval_returnValue;
      functionBody = `return emval_returnValue(toReturnWire, destructorsRef, ${functionBody})`;
    }
    functionBody = `return function (handle, methodName, destructorsRef, args) {
${functionBody}
}`;
    var invokerFunction = new Function(Object.keys(captures), functionBody)(...Object.values(captures));
    var functionName = `methodCaller<(${argTypes.map((t) => t.name)}) => ${retType.name}>`;
    return emval_addMethodCaller(createNamedFunction(functionName, invokerFunction));
  };
  var __emval_get_global = (name) => {
    if (!name) {
      return Emval.toHandle(globalThis);
    }
    name = getStringOrSymbol(name);
    return Emval.toHandle(globalThis[name]);
  };
  var __emval_get_property = (handle, key) => {
    handle = Emval.toValue(handle);
    key = Emval.toValue(key);
    return Emval.toHandle(handle[key]);
  };
  var __emval_incref = (handle) => {
    if (handle > 9) {
      emval_handles[handle + 1] += 1;
    }
  };
  var __emval_invoke = (caller, handle, methodName, destructorsRef, args) => emval_methodCallers[caller](handle, methodName, destructorsRef, args);
  var __emval_iter_begin = (iterable) => {
    iterable = Emval.toValue(iterable);
    return Emval.toHandle(iterable[Symbol.iterator]());
  };
  var __emval_iter_next = (iterator) => {
    iterator = Emval.toValue(iterator);
    var result = iterator.next();
    return result.done ? 0 : Emval.toHandle(result.value);
  };
  var __emval_new_cstring = (v) => Emval.toHandle(getStringOrSymbol(v));
  var __emval_new_object = () => Emval.toHandle({});
  var runDestructors = (destructors) => {
    while (destructors.length) {
      var ptr = destructors.pop();
      var del = destructors.pop();
      del(ptr);
    }
  };
  var __emval_run_destructors = (handle) => {
    var destructors = Emval.toValue(handle);
    runDestructors(destructors);
    __emval_decref(handle);
  };
  var __emval_set_property = (handle, key, value) => {
    handle = Emval.toValue(handle);
    key = Emval.toValue(key);
    value = Emval.toValue(value);
    handle[key] = value;
  };
  var __tzset_js = (timezone, daylight, std_name, dst_name) => {
    var currentYear = (/* @__PURE__ */ new Date()).getFullYear();
    var winter = new Date(currentYear, 0, 1);
    var summer = new Date(currentYear, 6, 1);
    var winterOffset = winter.getTimezoneOffset();
    var summerOffset = summer.getTimezoneOffset();
    var stdTimezoneOffset = Math.max(winterOffset, summerOffset);
    HEAPU32[timezone >> 2] = stdTimezoneOffset * 60;
    HEAP32[daylight >> 2] = Number(winterOffset != summerOffset);
    var extractZone = (timezoneOffset) => {
      var sign = timezoneOffset >= 0 ? "-" : "+";
      var absOffset = Math.abs(timezoneOffset);
      var hours = String(Math.floor(absOffset / 60)).padStart(2, "0");
      var minutes = String(absOffset % 60).padStart(2, "0");
      return `UTC${sign}${hours}${minutes}`;
    };
    var winterName = extractZone(winterOffset);
    var summerName = extractZone(summerOffset);
    if (summerOffset < winterOffset) {
      stringToUTF8(winterName, std_name, 17);
      stringToUTF8(summerName, dst_name, 17);
    } else {
      stringToUTF8(winterName, dst_name, 17);
      stringToUTF8(summerName, std_name, 17);
    }
  };
  var _emscripten_get_now = () => performance.timeOrigin + performance.now();
  var _emscripten_date_now = () => Date.now();
  var nowIsMonotonic = 1;
  var checkWasiClock = (clock_id) => clock_id >= 0 && clock_id <= 3;
  var INT53_MAX = 9007199254740992;
  var INT53_MIN = -9007199254740992;
  var bigintToI53Checked = (num) => num < INT53_MIN || num > INT53_MAX ? NaN : Number(num);
  function _clock_time_get(clk_id, ignored_precision, ptime) {
    ignored_precision = bigintToI53Checked(ignored_precision);
    if (!checkWasiClock(clk_id)) {
      return 28;
    }
    var now;
    if (clk_id === 0) {
      now = _emscripten_date_now();
    } else if (nowIsMonotonic) {
      now = _emscripten_get_now();
    } else {
      return 52;
    }
    var nsec = Math.round(now * 1e3 * 1e3);
    HEAP64[ptime >> 3] = BigInt(nsec);
    return 0;
  }
  var _emscripten_check_blocking_allowed = () => {
  };
  var _emscripten_exit_with_live_runtime = () => {
    runtimeKeepalivePush();
    throw "unwind";
  };
  var abortOnCannotGrowMemory = (requestedSize) => {
    abort("OOM");
  };
  var _emscripten_resize_heap = (requestedSize) => {
    var oldSize = HEAPU8.length;
    requestedSize >>>= 0;
    abortOnCannotGrowMemory(requestedSize);
  };
  var ENV = {};
  var getExecutableName = () => thisProgram || "./this.program";
  var getEnvStrings = () => {
    if (!getEnvStrings.strings) {
      var lang = (globalThis.navigator?.language ?? "C").replace("-", "_") + ".UTF-8";
      var env = { USER: "web_user", LOGNAME: "web_user", PATH: "/", PWD: "/", HOME: "/home/web_user", LANG: lang, _: getExecutableName() };
      for (var x in ENV) {
        if (ENV[x] === void 0)
          delete env[x];
        else
          env[x] = ENV[x];
      }
      var strings = [];
      for (var x in env) {
        strings.push(`${x}=${env[x]}`);
      }
      getEnvStrings.strings = strings;
    }
    return getEnvStrings.strings;
  };
  function _environ_get(__environ, environ_buf) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(15, 0, 1, __environ, environ_buf);
    var bufSize = 0;
    var envp = 0;
    for (var string of getEnvStrings()) {
      var ptr = environ_buf + bufSize;
      HEAPU32[__environ + envp >> 2] = ptr;
      bufSize += stringToUTF8(string, ptr, Infinity) + 1;
      envp += 4;
    }
    return 0;
  }
  function _environ_sizes_get(penviron_count, penviron_buf_size) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(16, 0, 1, penviron_count, penviron_buf_size);
    var strings = getEnvStrings();
    HEAPU32[penviron_count >> 2] = strings.length;
    var bufSize = 0;
    for (var string of strings) {
      bufSize += lengthBytesUTF8(string) + 1;
    }
    HEAPU32[penviron_buf_size >> 2] = bufSize;
    return 0;
  }
  function _fd_close(fd) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(17, 0, 1, fd);
    try {
      var stream = SYSCALLS.getStreamFromFD(fd);
      FS.close(stream);
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return e.errno;
    }
  }
  function _fd_fdstat_get(fd, pbuf) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(18, 0, 1, fd, pbuf);
    try {
      var rightsBase = 0;
      var rightsInheriting = 0;
      var flags = 0;
      {
        var stream = SYSCALLS.getStreamFromFD(fd);
        var type = stream.tty ? 2 : FS.isDir(stream.mode) ? 3 : FS.isLink(stream.mode) ? 7 : 4;
      }
      HEAP8[pbuf] = type;
      HEAP16[pbuf + 2 >> 1] = flags;
      HEAP64[pbuf + 8 >> 3] = BigInt(rightsBase);
      HEAP64[pbuf + 16 >> 3] = BigInt(rightsInheriting);
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return e.errno;
    }
  }
  var doReadv = (stream, iov, iovcnt, offset) => {
    var ret = 0;
    for (var i = 0; i < iovcnt; i++) {
      var ptr = HEAPU32[iov >> 2];
      var len = HEAPU32[iov + 4 >> 2];
      iov += 8;
      var curr = FS.read(stream, HEAP8, ptr, len, offset);
      if (curr < 0)
        return -1;
      ret += curr;
      if (curr < len)
        break;
      if (typeof offset != "undefined") {
        offset += curr;
      }
    }
    return ret;
  };
  function _fd_read(fd, iov, iovcnt, pnum) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(19, 0, 1, fd, iov, iovcnt, pnum);
    try {
      var stream = SYSCALLS.getStreamFromFD(fd);
      var num = doReadv(stream, iov, iovcnt);
      HEAPU32[pnum >> 2] = num;
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return e.errno;
    }
  }
  function _fd_seek(fd, offset, whence, newOffset) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(20, 0, 1, fd, offset, whence, newOffset);
    offset = bigintToI53Checked(offset);
    try {
      if (isNaN(offset))
        return 61;
      var stream = SYSCALLS.getStreamFromFD(fd);
      FS.llseek(stream, offset, whence);
      HEAP64[newOffset >> 3] = BigInt(stream.position);
      if (stream.getdents && offset === 0 && whence === 0)
        stream.getdents = null;
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return e.errno;
    }
  }
  var doWritev = (stream, iov, iovcnt, offset) => {
    var ret = 0;
    for (var i = 0; i < iovcnt; i++) {
      var ptr = HEAPU32[iov >> 2];
      var len = HEAPU32[iov + 4 >> 2];
      iov += 8;
      var curr = FS.write(stream, HEAP8, ptr, len, offset);
      if (curr < 0)
        return -1;
      ret += curr;
      if (curr < len) {
        break;
      }
      if (typeof offset != "undefined") {
        offset += curr;
      }
    }
    return ret;
  };
  function _fd_write(fd, iov, iovcnt, pnum) {
    if (ENVIRONMENT_IS_PTHREAD)
      return proxyToMainThread(21, 0, 1, fd, iov, iovcnt, pnum);
    try {
      var stream = SYSCALLS.getStreamFromFD(fd);
      var num = doWritev(stream, iov, iovcnt);
      HEAPU32[pnum >> 2] = num;
      return 0;
    } catch (e) {
      if (typeof FS == "undefined" || !(e.name === "ErrnoError"))
        throw e;
      return e.errno;
    }
  }
  var _llvm_eh_typeid_for = (type) => type;
  var stringToUTF8OnStack = (str) => {
    var size = lengthBytesUTF8(str) + 1;
    var ret = stackAlloc(size);
    stringToUTF8(str, ret, size);
    return ret;
  };
  var getCFunc = (ident) => {
    var func = Module["_" + ident];
    return func;
  };
  var writeArrayToMemory = (array, buffer) => {
    HEAP8.set(array, buffer);
  };
  var ccall = (ident, returnType, argTypes, args, opts) => {
    var toC = { string: (str) => {
      var ret2 = 0;
      if (str !== null && str !== void 0 && str !== 0) {
        ret2 = stringToUTF8OnStack(str);
      }
      return ret2;
    }, array: (arr) => {
      var ret2 = stackAlloc(arr.length);
      writeArrayToMemory(arr, ret2);
      return ret2;
    } };
    function convertReturnValue(ret2) {
      if (returnType === "string") {
        return UTF8ToString(ret2);
      }
      if (returnType === "boolean")
        return Boolean(ret2);
      return ret2;
    }
    var func = getCFunc(ident);
    var cArgs = [];
    var stack = 0;
    if (args) {
      for (var i = 0; i < args.length; i++) {
        var converter = toC[argTypes[i]];
        if (converter) {
          if (stack === 0)
            stack = stackSave();
          cArgs[i] = converter(args[i]);
        } else {
          cArgs[i] = args[i];
        }
      }
    }
    var previousAsync = Asyncify.currData;
    var ret = func(...cArgs);
    function onDone(ret2) {
      runtimeKeepalivePop();
      if (stack !== 0)
        stackRestore(stack);
      return convertReturnValue(ret2);
    }
    var asyncMode = opts?.async;
    runtimeKeepalivePush();
    if (Asyncify.currData != previousAsync) {
      return Asyncify.whenDone().then(onDone);
    }
    ret = onDone(ret);
    if (asyncMode)
      return Promise.resolve(ret);
    return ret;
  };
  PThread.init();
  FS.createPreloadedFile = FS_createPreloadedFile;
  FS.preloadFile = FS_preloadFile;
  FS.staticInit();
  {
    initMemory();
  }
  Module["stackAlloc"] = stackAlloc;
  Module["ccall"] = ccall;
  Module["stringToUTF8OnStack"] = stringToUTF8OnStack;
  Module["FS"] = FS;
  var proxiedFunctionTable = [_proc_exit, exitOnMainThread, pthreadCreateProxied, ___syscall_accept4, ___syscall_bind, ___syscall_connect, ___syscall_fcntl64, ___syscall_ioctl, ___syscall_listen, ___syscall_openat, ___syscall_pipe, ___syscall_poll, ___syscall_recvfrom, ___syscall_sendto, ___syscall_socket, _environ_get, _environ_sizes_get, _fd_close, _fd_fdstat_get, _fd_read, _fd_seek, _fd_write];
  function __asyncjs__em_libusb_wait_async(ptr, expected_value, timeout) {
    return Asyncify.handleAsync(async () => {
      await Atomics.waitAsync(HEAP32, ptr >> 2, expected_value, timeout).value;
    });
  }
  function usbi_em_promise_catch(handle) {
    let promise = Emval.toValue(handle);
    promise = promise.then((value) => ({ error: 0, value }), (error) => {
      console.error(error);
      let errorCode = -99;
      if (error instanceof DOMException) {
        const ERROR_CODES = { NetworkError: -1, DataError: -2, TypeMismatchError: -2, IndexSizeError: -2, SecurityError: -3, NotFoundError: -5, InvalidStateError: -6, TimeoutError: -7, AbortError: -10, NotSupportedError: -12 };
        errorCode = ERROR_CODES[error.name] ?? errorCode;
      } else if (error instanceof RangeError || error instanceof TypeError) {
        errorCode = -2;
      }
      return { error: errorCode, value: void 0 };
    });
    return Emval.toHandle(promise);
  }
  function usbi_em_copy_from_dataview(dst, src) {
    src = Emval.toValue(src);
    src = new Uint8Array(src.buffer, src.byteOffset, src.byteLength);
    HEAPU8.set(src, dst);
  }
  function usbi_em_device_safe_open_close(device, open) {
    device = Emval.toValue(device);
    const symbol = Symbol.for("libusb.open_close_chain");
    let promiseChain = device[symbol] ?? Promise.resolve(0);
    device[symbol] = promiseChain = promiseChain.then(async (refCount) => {
      if (open) {
        if (!refCount++) {
          await device.open();
        }
      } else {
        if (!--refCount) {
          await device.close();
        }
      }
      return refCount;
    });
    return Emval.toHandle(promiseChain);
  }
  var ___getTypeName, __embind_initialize_bindings, __emval_coro_resume, __emval_coro_reject, _main, _free, _malloc, _ntohs, _htons, _pthread_self, __emscripten_tls_init, ___funcs_on_exit, __emscripten_thread_init, __emscripten_thread_crashed, _fflush, __emscripten_run_js_on_main_thread_done, __emscripten_run_js_on_main_thread, __emscripten_thread_free_data, __emscripten_thread_exit, __emscripten_check_mailbox, _setThrew, __emscripten_tempret_set, _emscripten_stack_set_limits, __emscripten_stack_restore, __emscripten_stack_alloc, _emscripten_stack_get_current, ___cxa_decrement_exception_refcount, ___cxa_increment_exception_refcount, ___cxa_can_catch, ___cxa_get_exception_ptr, dynCall_iii, dynCall_viiii, dynCall_vii, dynCall_ii, dynCall_viii, dynCall_iiii, dynCall_iiiii, dynCall_iiiiii, dynCall_vi, dynCall_v, dynCall_iiiiiii, dynCall_iiiiiiiiiiiii, dynCall_iiiiiiiiiiiiiiiii, dynCall_iiiiiiii, dynCall_iiiiiiiiiii, dynCall_iiiiiiiiii, dynCall_iiiiiiiiiiii, dynCall_viiiiiii, dynCall_dii, dynCall_viiiii, dynCall_viiiiii, dynCall_iiji, dynCall_iiiiiiiii, dynCall_vij, dynCall_ji, dynCall_iid, dynCall_iijj, dynCall_iij, dynCall_jiii, dynCall_i, dynCall_jiji, dynCall_iidiiii, dynCall_viijii, dynCall_jiiii, dynCall_fiii, dynCall_diii, dynCall_viiiiiiiiii, dynCall_viiiiiiiiiiiiiii, dynCall_iiiiij, dynCall_iiiiid, dynCall_iiiiijj, dynCall_iiiiiijj, _asyncify_start_unwind, _asyncify_stop_unwind, _asyncify_start_rewind, _asyncify_stop_rewind, __indirect_function_table, wasmTable;
  function assignWasmExports(wasmExports2) {
    ___getTypeName = wasmExports2["gb"];
    __embind_initialize_bindings = wasmExports2["hb"];
    __emval_coro_resume = wasmExports2["ib"];
    __emval_coro_reject = wasmExports2["jb"];
    _main = Module["_main"] = wasmExports2["lb"];
    _free = wasmExports2["mb"];
    _malloc = wasmExports2["nb"];
    _ntohs = wasmExports2["ob"];
    _htons = wasmExports2["pb"];
    _pthread_self = wasmExports2["qb"];
    __emscripten_tls_init = wasmExports2["rb"];
    ___funcs_on_exit = wasmExports2["sb"];
    __emscripten_thread_init = wasmExports2["tb"];
    __emscripten_thread_crashed = wasmExports2["ub"];
    _fflush = Module["_fflush"] = wasmExports2["vb"];
    __emscripten_run_js_on_main_thread_done = wasmExports2["wb"];
    __emscripten_run_js_on_main_thread = wasmExports2["xb"];
    __emscripten_thread_free_data = wasmExports2["yb"];
    __emscripten_thread_exit = wasmExports2["zb"];
    __emscripten_check_mailbox = wasmExports2["Ab"];
    _setThrew = wasmExports2["Bb"];
    __emscripten_tempret_set = wasmExports2["Cb"];
    _emscripten_stack_set_limits = wasmExports2["Db"];
    __emscripten_stack_restore = wasmExports2["Eb"];
    __emscripten_stack_alloc = wasmExports2["Fb"];
    _emscripten_stack_get_current = wasmExports2["Gb"];
    ___cxa_decrement_exception_refcount = wasmExports2["Hb"];
    ___cxa_increment_exception_refcount = wasmExports2["Ib"];
    ___cxa_can_catch = wasmExports2["Jb"];
    ___cxa_get_exception_ptr = wasmExports2["Kb"];
    dynCall_iii = dynCalls["iii"] = wasmExports2["Lb"];
    dynCall_viiii = dynCalls["viiii"] = wasmExports2["Mb"];
    dynCall_vii = dynCalls["vii"] = wasmExports2["Nb"];
    dynCall_ii = dynCalls["ii"] = wasmExports2["Ob"];
    dynCall_viii = dynCalls["viii"] = wasmExports2["Pb"];
    dynCall_iiii = dynCalls["iiii"] = wasmExports2["Qb"];
    dynCall_iiiii = dynCalls["iiiii"] = wasmExports2["Rb"];
    dynCall_iiiiii = dynCalls["iiiiii"] = wasmExports2["Sb"];
    dynCall_vi = dynCalls["vi"] = wasmExports2["Tb"];
    dynCall_v = dynCalls["v"] = wasmExports2["Ub"];
    dynCall_iiiiiii = dynCalls["iiiiiii"] = wasmExports2["Vb"];
    dynCall_iiiiiiiiiiiii = dynCalls["iiiiiiiiiiiii"] = wasmExports2["Wb"];
    dynCall_iiiiiiiiiiiiiiiii = dynCalls["iiiiiiiiiiiiiiiii"] = wasmExports2["Xb"];
    dynCall_iiiiiiii = dynCalls["iiiiiiii"] = wasmExports2["Yb"];
    dynCall_iiiiiiiiiii = dynCalls["iiiiiiiiiii"] = wasmExports2["Zb"];
    dynCall_iiiiiiiiii = dynCalls["iiiiiiiiii"] = wasmExports2["_b"];
    dynCall_iiiiiiiiiiii = dynCalls["iiiiiiiiiiii"] = wasmExports2["$b"];
    dynCall_viiiiiii = dynCalls["viiiiiii"] = wasmExports2["ac"];
    dynCall_dii = dynCalls["dii"] = wasmExports2["bc"];
    dynCall_viiiii = dynCalls["viiiii"] = wasmExports2["cc"];
    dynCall_viiiiii = dynCalls["viiiiii"] = wasmExports2["dc"];
    dynCall_iiji = dynCalls["iiji"] = wasmExports2["ec"];
    dynCall_iiiiiiiii = dynCalls["iiiiiiiii"] = wasmExports2["fc"];
    dynCall_vij = dynCalls["vij"] = wasmExports2["gc"];
    dynCall_ji = dynCalls["ji"] = wasmExports2["hc"];
    dynCall_iid = dynCalls["iid"] = wasmExports2["ic"];
    dynCall_iijj = dynCalls["iijj"] = wasmExports2["jc"];
    dynCall_iij = dynCalls["iij"] = wasmExports2["kc"];
    dynCall_jiii = dynCalls["jiii"] = wasmExports2["lc"];
    dynCall_i = dynCalls["i"] = wasmExports2["mc"];
    dynCall_jiji = dynCalls["jiji"] = wasmExports2["nc"];
    dynCall_iidiiii = dynCalls["iidiiii"] = wasmExports2["oc"];
    dynCall_viijii = dynCalls["viijii"] = wasmExports2["pc"];
    dynCall_jiiii = dynCalls["jiiii"] = wasmExports2["qc"];
    dynCall_fiii = dynCalls["fiii"] = wasmExports2["rc"];
    dynCall_diii = dynCalls["diii"] = wasmExports2["sc"];
    dynCall_viiiiiiiiii = dynCalls["viiiiiiiiii"] = wasmExports2["tc"];
    dynCall_viiiiiiiiiiiiiii = dynCalls["viiiiiiiiiiiiiii"] = wasmExports2["uc"];
    dynCall_iiiiij = dynCalls["iiiiij"] = wasmExports2["vc"];
    dynCall_iiiiid = dynCalls["iiiiid"] = wasmExports2["wc"];
    dynCall_iiiiijj = dynCalls["iiiiijj"] = wasmExports2["xc"];
    dynCall_iiiiiijj = dynCalls["iiiiiijj"] = wasmExports2["yc"];
    _asyncify_start_unwind = wasmExports2["zc"];
    _asyncify_stop_unwind = wasmExports2["Ac"];
    _asyncify_start_rewind = wasmExports2["Bc"];
    _asyncify_stop_rewind = wasmExports2["Cc"];
    __indirect_function_table = wasmTable = wasmExports2["kb"];
  }
  var wasmImports;
  function assignWasmImports() {
    wasmImports = { l: ___assert_fail, Ta: __asyncjs__em_libusb_wait_async, q: ___cxa_begin_catch, u: ___cxa_end_catch, b: ___cxa_find_matching_catch_2, g: ___cxa_find_matching_catch_3, E: ___cxa_find_matching_catch_4, ia: ___cxa_rethrow, r: ___cxa_throw, ta: ___cxa_uncaught_exceptions, za: ___pthread_create_js, f: ___resumeException, pa: ___syscall_accept4, oa: ___syscall_bind, na: ___syscall_connect, H: ___syscall_fcntl64, Ha: ___syscall_ioctl, ma: ___syscall_listen, Ia: ___syscall_openat, Aa: ___syscall_pipe, ea: ___syscall_poll, eb: ___syscall_recvfrom, db: ___syscall_sendto, cb: ___syscall_socket, va: __abort_js, la: __embind_register_bigint, ab: __embind_register_bool, _a: __embind_register_emval, ka: __embind_register_float, K: __embind_register_integer, C: __embind_register_memory_view, $a: __embind_register_std_string, _: __embind_register_std_wstring, bb: __embind_register_void, Da: __emscripten_init_main_thread_js, xa: __emscripten_notify_mailbox_postmessage, da: __emscripten_receive_on_main_thread_js, ba: __emscripten_thread_cleanup, Ca: __emscripten_thread_mailbox_await, Ka: __emscripten_thread_set_strongref, M: __emval_await, Sa: __emval_coro_make_promise, Ra: __emval_coro_suspend, A: __emval_create_invoker, n: __emval_decref, ha: __emval_get_global, ga: __emval_get_property, w: __emval_incref, z: __emval_invoke, Na: __emval_iter_begin, Qa: __emval_iter_next, O: __emval_new_cstring, Oa: __emval_new_object, y: __emval_run_destructors, T: __emval_set_property, qa: __tzset_js, Ma: _clock_time_get, ca: _emscripten_check_blocking_allowed, La: _emscripten_date_now, Ja: _emscripten_exit_with_live_runtime, L: _emscripten_get_now, wa: _emscripten_resize_heap, Fa: _environ_get, Ga: _environ_sizes_get, ya: _exit, S: _fd_close, Ea: _fd_fdstat_get, fa: _fd_read, Ba: _fd_seek, V: _fd_write, Ya: invoke_dii, $: invoke_diii, aa: invoke_fiii, x: invoke_i, i: invoke_ii, J: invoke_iid, c: invoke_iii, d: invoke_iiii, m: invoke_iiiii, ra: invoke_iiiiid, k: invoke_iiiiii, v: invoke_iiiiiii, s: invoke_iiiiiiii, Xa: invoke_iiiiiiiii, U: invoke_iiiiiiiiii, Z: invoke_iiiiiiiiiii, P: invoke_iiiiiiiiiiii, ja: invoke_iiiiiiiiiiiii, Za: invoke_iiiiiiiiiiiiiiiii, sa: invoke_iiiiij, Va: invoke_iij, X: invoke_iiji, Wa: invoke_iijj, F: invoke_ji, Ua: invoke_jiii, R: invoke_jiiii, o: invoke_v, j: invoke_vi, e: invoke_vii, h: invoke_viii, p: invoke_viiii, B: invoke_viiiii, Y: invoke_viiiiii, G: invoke_viiiiiii, N: invoke_viiiiiiiiii, Q: invoke_viiiiiiiiiiiiiii, ua: invoke_viijii, D: invoke_vij, t: _llvm_eh_typeid_for, a: wasmMemory, W: usbi_em_copy_from_dataview, Pa: usbi_em_device_safe_open_close, I: usbi_em_promise_catch };
  }
  function invoke_iii(index, a1, a2) {
    var sp = stackSave();
    try {
      return dynCall_iii(index, a1, a2);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viiii(index, a1, a2, a3, a4) {
    var sp = stackSave();
    try {
      dynCall_viiii(index, a1, a2, a3, a4);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_vii(index, a1, a2) {
    var sp = stackSave();
    try {
      dynCall_vii(index, a1, a2);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viii(index, a1, a2, a3) {
    var sp = stackSave();
    try {
      dynCall_viii(index, a1, a2, a3);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiii(index, a1, a2, a3) {
    var sp = stackSave();
    try {
      return dynCall_iiii(index, a1, a2, a3);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_ii(index, a1) {
    var sp = stackSave();
    try {
      return dynCall_ii(index, a1);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiii(index, a1, a2, a3, a4) {
    var sp = stackSave();
    try {
      return dynCall_iiiii(index, a1, a2, a3, a4);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiii(index, a1, a2, a3, a4, a5) {
    var sp = stackSave();
    try {
      return dynCall_iiiiii(index, a1, a2, a3, a4, a5);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiii(index, a1, a2, a3, a4, a5, a6) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiii(index, a1, a2, a3, a4, a5, a6);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_vi(index, a1) {
    var sp = stackSave();
    try {
      dynCall_vi(index, a1);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_v(index) {
    var sp = stackSave();
    try {
      dynCall_v(index);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiiiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiiiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiiii(index, a1, a2, a3, a4, a5, a6, a7) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiiii(index, a1, a2, a3, a4, a5, a6, a7);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viiiiiii(index, a1, a2, a3, a4, a5, a6, a7) {
    var sp = stackSave();
    try {
      dynCall_viiiiiii(index, a1, a2, a3, a4, a5, a6, a7);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_dii(index, a1, a2) {
    var sp = stackSave();
    try {
      return dynCall_dii(index, a1, a2);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viiiii(index, a1, a2, a3, a4, a5) {
    var sp = stackSave();
    try {
      dynCall_viiiii(index, a1, a2, a3, a4, a5);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viiiiii(index, a1, a2, a3, a4, a5, a6) {
    var sp = stackSave();
    try {
      dynCall_viiiiii(index, a1, a2, a3, a4, a5, a6);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiji(index, a1, a2, a3) {
    var sp = stackSave();
    try {
      return dynCall_iiji(index, a1, a2, a3);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8) {
    var sp = stackSave();
    try {
      return dynCall_iiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_vij(index, a1, a2) {
    var sp = stackSave();
    try {
      dynCall_vij(index, a1, a2);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_ji(index, a1) {
    var sp = stackSave();
    try {
      return dynCall_ji(index, a1);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
      return 0n;
    }
  }
  function invoke_iid(index, a1, a2) {
    var sp = stackSave();
    try {
      return dynCall_iid(index, a1, a2);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iijj(index, a1, a2, a3) {
    var sp = stackSave();
    try {
      return dynCall_iijj(index, a1, a2, a3);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iij(index, a1, a2) {
    var sp = stackSave();
    try {
      return dynCall_iij(index, a1, a2);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_jiii(index, a1, a2, a3) {
    var sp = stackSave();
    try {
      return dynCall_jiii(index, a1, a2, a3);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
      return 0n;
    }
  }
  function invoke_i(index) {
    var sp = stackSave();
    try {
      return dynCall_i(index);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viijii(index, a1, a2, a3, a4, a5) {
    var sp = stackSave();
    try {
      dynCall_viijii(index, a1, a2, a3, a4, a5);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiij(index, a1, a2, a3, a4, a5) {
    var sp = stackSave();
    try {
      return dynCall_iiiiij(index, a1, a2, a3, a4, a5);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_iiiiid(index, a1, a2, a3, a4, a5) {
    var sp = stackSave();
    try {
      return dynCall_iiiiid(index, a1, a2, a3, a4, a5);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_jiiii(index, a1, a2, a3, a4) {
    var sp = stackSave();
    try {
      return dynCall_jiiii(index, a1, a2, a3, a4);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
      return 0n;
    }
  }
  function invoke_fiii(index, a1, a2, a3) {
    var sp = stackSave();
    try {
      return dynCall_fiii(index, a1, a2, a3);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_diii(index, a1, a2, a3) {
    var sp = stackSave();
    try {
      return dynCall_diii(index, a1, a2, a3);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10) {
    var sp = stackSave();
    try {
      dynCall_viiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function invoke_viiiiiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15) {
    var sp = stackSave();
    try {
      dynCall_viiiiiiiiiiiiiii(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15);
    } catch (e) {
      stackRestore(sp);
      if (e !== e + 0)
        throw e;
      _setThrew(1, 0);
    }
  }
  function callMain(args = []) {
    var entryFunction = _main;
    args.unshift(thisProgram);
    var argc = args.length;
    var argv = stackAlloc((argc + 1) * 4);
    var argv_ptr = argv;
    for (var arg of args) {
      HEAPU32[argv_ptr >> 2] = stringToUTF8OnStack(arg);
      argv_ptr += 4;
    }
    HEAPU32[argv_ptr >> 2] = 0;
    try {
      var ret = entryFunction(argc, argv);
      exitJS(ret, true);
      return ret;
    } catch (e) {
      return handleException(e);
    }
  }
  function run(args = arguments_) {
    if (runDependencies > 0) {
      dependenciesFulfilled = run;
      return;
    }
    if (ENVIRONMENT_IS_PTHREAD) {
      readyPromiseResolve?.(Module);
      initRuntime();
      return;
    }
    preRun();
    if (runDependencies > 0) {
      dependenciesFulfilled = run;
      return;
    }
    function doRun() {
      Module["calledRun"] = true;
      if (ABORT)
        return;
      initRuntime();
      preMain();
      readyPromiseResolve?.(Module);
      var noInitialRun = true;
      if (!noInitialRun)
        callMain(args);
      postRun();
    }
    {
      doRun();
    }
  }
  var wasmExports;
  if (!ENVIRONMENT_IS_PTHREAD) {
    wasmExports = await createWasm();
    run();
  }
  if (runtimeInitialized) {
    moduleRtn = Module;
  } else {
    moduleRtn = new Promise((resolve, reject) => {
      readyPromiseResolve = resolve;
      readyPromiseReject = reject;
    });
  }
  ;
  return moduleRtn;
}
var openFPGALoader_default = instantiate;
var isPthread = globalThis.name == "em-pthread";
isPthread && instantiate();

// node_modules/@yowasp/runtime/lib/util.js
function lineBuffered(processLine) {
  let buffer = new Uint8Array();
  return (bytes) => {
    if (bytes === null)
      return;
    let newBuffer = new Uint8Array(buffer.length + bytes.length);
    newBuffer.set(buffer);
    newBuffer.set(bytes, buffer.length);
    buffer = newBuffer;
    let newlineAt = -1;
    while (true) {
      const nextNewlineAt = buffer.indexOf(10, newlineAt + 1);
      if (nextNewlineAt === -1)
        break;
      processLine(new TextDecoder().decode(buffer.subarray(newlineAt + 1, nextNewlineAt)));
      newlineAt = nextNewlineAt;
    }
    buffer = buffer.subarray(newlineAt + 1);
  };
}

// lib/api.js
var Exit = class extends Error {
  constructor(code, files) {
    super(`Exited with status ${code}`);
    this.code = code;
    this.files = files;
  }
};
function createStreamDevice(FS, path, index, ops) {
  const dev = FS.makedev(2, index);
  FS.registerDevice(dev, {
    open(stream) {
      stream.seekable = false;
    },
    read(stream, buffer, offset, length, pos) {
      throw new FS.ErrnoError(29);
    },
    write(stream, buffer, offset, length, pos) {
      if (ops.write !== void 0) {
        ops.write(new Uint8Array(buffer.slice(offset, offset + length)));
        return length;
      }
      throw new FS.ErrnoError(29);
    },
    fsync(stream) {
      if (ops.write !== void 0)
        ops.write(null);
    }
  });
  FS.mkdev(path, dev);
  return path;
}
function createStandardStreams(FS, { stdout, stderr }) {
  const lineBufferedConsole = lineBuffered(console.log);
  function makeStream(streamOption) {
    if (streamOption === void 0)
      return lineBufferedConsole;
    if (streamOption === null)
      return (_bytes) => {
      };
    return streamOption;
  }
  createStreamDevice(FS, "/dev/stdin", 0, {});
  createStreamDevice(FS, "/dev/stdout", 1, { write: makeStream(stdout) });
  createStreamDevice(FS, "/dev/stderr", 2, { write: makeStream(stderr) });
  FS.open("/dev/stdin", 0);
  FS.open("/dev/stdout", 1);
  FS.open("/dev/stderr", 1);
}
function writeTree(FS, tree, path = "/") {
  for (const [filename, data] of Object.entries(tree)) {
    const filepath = `${path}${filename}`;
    if (typeof data === "string" || data instanceof Uint8Array) {
      FS.writeFile(filepath, data);
    } else {
      FS.mkdir(filepath);
      writeTree(FS, data, `${filepath}/`);
    }
  }
}
function readTree(FS, path = "/") {
  const tree = {};
  for (const filename of FS.readdir(path)) {
    const filepath = `${path}${filename}`;
    if (filename === "." || filename === "..")
      continue;
    if (["/tmp", "/dev", "/proc"].includes(filepath))
      continue;
    const stat = FS.stat(filepath);
    if (FS.isFile(stat.mode)) {
      tree[filename] = FS.readFile(filepath, { encoding: "binary" });
    } else if (FS.isDir(stat.mode)) {
      tree[filename] = readTree(FS, `${filepath}/`);
    }
  }
  return tree;
}
async function runOpenFPGALoader(args = null, filesIn = {}, options = {}) {
  if (args === null)
    return;
  const inst = await openFPGALoader_default({ noFSInit: true });
  createStandardStreams(inst.FS, options);
  writeTree(inst.FS, filesIn);
  const argv = ["openFPGALoader", ...args, null];
  const argvPtr = inst.stackAlloc(argv.length * 4);
  argv.forEach((arg, off) => inst.HEAPU32[(argvPtr >> 2) + off] = arg === null ? 0 : inst.stringToUTF8OnStack(arg));
  const exitCode = await inst.ccall(
    "main",
    "number",
    ["number", "number"],
    [argv.length - 1, argvPtr],
    { async: true }
  );
  inst._fflush(0);
  const filesOut = readTree(inst.FS);
  if (exitCode == 0) {
    return filesOut;
  } else {
    throw new Exit(exitCode, filesOut);
  }
}
runOpenFPGALoader.requiresUSBDevice = [];
var commands = {
  openFPGALoader: runOpenFPGALoader
};
export {
  Exit,
  commands,
  runOpenFPGALoader
};

(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __name = (target, value) => __defProp(target, "name", { value, configurable: true });
  var __esm = (fn, res) => function __init() {
    return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
  };
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // node_modules/@overextended/ox_lib/dist/common/cache/index.js
  var cacheEvents, cache;
  var init_cache = __esm({
    "node_modules/@overextended/ox_lib/dist/common/cache/index.js"() {
      cacheEvents = {};
      cache = new Proxy({
        resource: GetCurrentResourceName(),
        game: GetGameName()
      }, { get(target, key) {
        const result = key ? target[key] : target;
        if (result !== void 0) return result;
        cacheEvents[key] = [];
        AddEventHandler(`ox_lib:cache:${key}`, (value) => {
          const oldValue = target[key];
          cacheEvents[key].forEach((cb) => cb(value, oldValue));
          target[key] = value;
        });
        target[key] = exports.ox_lib.cache(key) || false;
        return target[key];
      } });
    }
  });

  // node_modules/@overextended/ox_lib/dist/common/misc.js
  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms, null));
  }
  async function waitFor(cb, errMessage, timeout) {
    let value = await cb();
    if (value !== void 0) return value;
    if (timeout || timeout == null) {
      if (typeof timeout !== "number") timeout = 1e3;
    }
    const start = GetGameTimer();
    let id;
    return new Promise((resolve, reject) => {
      id = setTick(async () => {
        const elapsed = timeout && GetGameTimer() - start;
        if (elapsed && elapsed > timeout) return reject(`${errMessage || "failed to resolve callback"} (waited ${elapsed}ms)`);
        value = await cb();
        if (value !== void 0) resolve(value);
      });
    }).finally(() => clearTick(id));
  }
  var context;
  var init_misc = __esm({
    "node_modules/@overextended/ox_lib/dist/common/misc.js"() {
      context = IsDuplicityVersion() ? "server" : "client";
      __name(sleep, "sleep");
      __name(waitFor, "waitFor");
    }
  });

  // node_modules/fast-printf/dist/src/boolean.js
  var require_boolean = __commonJS({
    "node_modules/fast-printf/dist/src/boolean.js"(exports2) {
      "use strict";
      Object.defineProperty(exports2, "__esModule", { value: true });
      exports2.boolean = void 0;
      var boolean = /* @__PURE__ */ __name(function(value) {
        switch (Object.prototype.toString.call(value)) {
          case "[object String]":
            return ["true", "t", "yes", "y", "on", "1"].includes(value.trim().toLowerCase());
          case "[object Number]":
            return value.valueOf() === 1;
          case "[object Boolean]":
            return value.valueOf();
          default:
            return false;
        }
      }, "boolean");
      exports2.boolean = boolean;
    }
  });

  // node_modules/fast-printf/dist/src/tokenize.js
  var require_tokenize = __commonJS({
    "node_modules/fast-printf/dist/src/tokenize.js"(exports2) {
      "use strict";
      Object.defineProperty(exports2, "__esModule", { value: true });
      exports2.tokenize = void 0;
      var TokenRule = /(?:%(?<flag>([+0-]|-\+))?(?<width>\d+)?(?<position>\d+\$)?(?<precision>\.\d+)?(?<conversion>[%BCESb-iosux]))|(\\%)/g;
      var tokenize = /* @__PURE__ */ __name((subject) => {
        let matchResult;
        const tokens = [];
        let argumentIndex = 0;
        let lastIndex = 0;
        let lastToken = null;
        while ((matchResult = TokenRule.exec(subject)) !== null) {
          if (matchResult.index > lastIndex) {
            lastToken = {
              literal: subject.slice(lastIndex, matchResult.index),
              type: "literal"
            };
            tokens.push(lastToken);
          }
          const match = matchResult[0];
          lastIndex = matchResult.index + match.length;
          if (match === "\\%" || match === "%%") {
            if (lastToken && lastToken.type === "literal") {
              lastToken.literal += "%";
            } else {
              lastToken = {
                literal: "%",
                type: "literal"
              };
              tokens.push(lastToken);
            }
          } else if (matchResult.groups) {
            lastToken = {
              conversion: matchResult.groups.conversion,
              // eslint-disable-next-line @typescript-eslint/no-explicit-any -- intentional per @gajus
              flag: matchResult.groups.flag || null,
              placeholder: match,
              position: matchResult.groups.position ? Number.parseInt(matchResult.groups.position, 10) - 1 : argumentIndex++,
              precision: matchResult.groups.precision ? Number.parseInt(matchResult.groups.precision.slice(1), 10) : null,
              type: "placeholder",
              width: matchResult.groups.width ? Number.parseInt(matchResult.groups.width, 10) : null
            };
            tokens.push(lastToken);
          }
        }
        if (lastIndex <= subject.length - 1) {
          if (lastToken && lastToken.type === "literal") {
            lastToken.literal += subject.slice(lastIndex);
          } else {
            tokens.push({
              literal: subject.slice(lastIndex),
              type: "literal"
            });
          }
        }
        return tokens;
      }, "tokenize");
      exports2.tokenize = tokenize;
    }
  });

  // node_modules/fast-printf/dist/src/createPrintf.js
  var require_createPrintf = __commonJS({
    "node_modules/fast-printf/dist/src/createPrintf.js"(exports2) {
      "use strict";
      Object.defineProperty(exports2, "__esModule", { value: true });
      exports2.createPrintf = void 0;
      var boolean_1 = require_boolean();
      var tokenize_1 = require_tokenize();
      var formatDefaultUnboundExpression = /* @__PURE__ */ __name((_subject, token) => {
        return token.placeholder;
      }, "formatDefaultUnboundExpression");
      var createPrintf = /* @__PURE__ */ __name((configuration) => {
        var _a;
        const padValue = /* @__PURE__ */ __name((value, width, flag) => {
          if (flag === "-") {
            return value.padEnd(width, " ");
          } else if (flag === "-+") {
            return ((Number(value) >= 0 ? "+" : "") + value).padEnd(width, " ");
          } else if (flag === "+") {
            return ((Number(value) >= 0 ? "+" : "") + value).padStart(width, " ");
          } else if (flag === "0") {
            return value.padStart(width, "0");
          } else {
            return value.padStart(width, " ");
          }
        }, "padValue");
        const formatUnboundExpression = (_a = configuration === null || configuration === void 0 ? void 0 : configuration.formatUnboundExpression) !== null && _a !== void 0 ? _a : formatDefaultUnboundExpression;
        const cache2 = {};
        return (subject, ...boundValues) => {
          let tokens = cache2[subject];
          if (!tokens) {
            tokens = cache2[subject] = (0, tokenize_1.tokenize)(subject);
          }
          let result = "";
          for (const token of tokens) {
            if (token.type === "literal") {
              result += token.literal;
            } else {
              let boundValue = boundValues[token.position];
              if (boundValue === void 0) {
                result += formatUnboundExpression(subject, token, boundValues);
              } else if (token.conversion === "b") {
                result += (0, boolean_1.boolean)(boundValue) ? "true" : "false";
              } else if (token.conversion === "B") {
                result += (0, boolean_1.boolean)(boundValue) ? "TRUE" : "FALSE";
              } else if (token.conversion === "c") {
                result += boundValue;
              } else if (token.conversion === "C") {
                result += String(boundValue).toUpperCase();
              } else if (token.conversion === "i" || token.conversion === "d") {
                boundValue = String(Math.trunc(boundValue));
                if (token.width !== null) {
                  boundValue = padValue(boundValue, token.width, token.flag);
                }
                result += boundValue;
              } else if (token.conversion === "e") {
                result += Number(boundValue).toExponential();
              } else if (token.conversion === "E") {
                result += Number(boundValue).toExponential().toUpperCase();
              } else if (token.conversion === "f") {
                if (token.precision !== null) {
                  boundValue = Number(boundValue).toFixed(token.precision);
                }
                if (token.width !== null) {
                  boundValue = padValue(String(boundValue), token.width, token.flag);
                }
                result += boundValue;
              } else if (token.conversion === "o") {
                result += (Number.parseInt(String(boundValue), 10) >>> 0).toString(8);
              } else if (token.conversion === "s") {
                if (token.width !== null) {
                  boundValue = padValue(String(boundValue), token.width, token.flag);
                }
                result += boundValue;
              } else if (token.conversion === "S") {
                if (token.width !== null) {
                  boundValue = padValue(String(boundValue), token.width, token.flag);
                }
                result += String(boundValue).toUpperCase();
              } else if (token.conversion === "u") {
                result += Number.parseInt(String(boundValue), 10) >>> 0;
              } else if (token.conversion === "x") {
                boundValue = (Number.parseInt(String(boundValue), 10) >>> 0).toString(16);
                if (token.width !== null) {
                  boundValue = padValue(String(boundValue), token.width, token.flag);
                }
                result += boundValue;
              } else {
                throw new Error("Unknown format specifier.");
              }
            }
          }
          return result;
        };
      }, "createPrintf");
      exports2.createPrintf = createPrintf;
    }
  });

  // node_modules/fast-printf/dist/src/printf.js
  var require_printf = __commonJS({
    "node_modules/fast-printf/dist/src/printf.js"(exports2) {
      "use strict";
      Object.defineProperty(exports2, "__esModule", { value: true });
      exports2.printf = exports2.createPrintf = void 0;
      var createPrintf_1 = require_createPrintf();
      Object.defineProperty(exports2, "createPrintf", { enumerable: true, get: /* @__PURE__ */ __name(function() {
        return createPrintf_1.createPrintf;
      }, "get") });
      exports2.printf = (0, createPrintf_1.createPrintf)();
    }
  });

  // node_modules/@overextended/ox_lib/dist/common/locale/index.js
  function flattenDict(source2, target, prefix) {
    for (const key in source2) {
      const fullKey = prefix ? `${prefix}.${key}` : key;
      const value = source2[key];
      if (typeof value === "object") flattenDict(value, target, fullKey);
      else target[fullKey] = String(value);
    }
    return target;
  }
  function locale(str, ...args) {
    const lstr = dict[str];
    if (!lstr) return str;
    if (lstr) {
      if (typeof lstr !== "string") return lstr;
      if (args.length > 0) return (0, import_fast_printf.printf)(lstr, ...args);
      return lstr;
    }
    return str;
  }
  function loadLocale(key) {
    const data = LoadResourceFile(cache.resource, `locales/${key}.json`);
    if (!data) console.warn(`could not load 'locales/${key}.json'`);
    return JSON.parse(data) || {};
  }
  var import_fast_printf, dict, initLocale;
  var init_locale = __esm({
    "node_modules/@overextended/ox_lib/dist/common/locale/index.js"() {
      init_cache();
      import_fast_printf = __toESM(require_printf(), 1);
      dict = {};
      __name(flattenDict, "flattenDict");
      __name(locale, "locale");
      __name(loadLocale, "loadLocale");
      initLocale = /* @__PURE__ */ __name((key) => {
        const lang = key || exports.ox_lib.getLocaleKey();
        let locales = loadLocale("en");
        if (lang !== "en") Object.assign(locales, loadLocale(lang));
        const flattened = flattenDict(locales, {});
        for (let [k, v] of Object.entries(flattened)) {
          if (typeof v === "string") {
            const regExp = /* @__PURE__ */ new RegExp(/\$\{([^}]+)\}/g);
            const matches = v.match(regExp);
            if (matches) for (const match of matches) {
              if (!match) break;
              let locale2 = flattened[match.substring(2, match.length - 1)];
              if (locale2) v = v.replace(match, locale2);
            }
          }
          dict[k] = v;
        }
      }, "initLocale");
      initLocale();
    }
  });

  // node_modules/@overextended/ox_lib/dist/common/version/index.js
  var checkDependency;
  var init_version = __esm({
    "node_modules/@overextended/ox_lib/dist/common/version/index.js"() {
      checkDependency = /* @__PURE__ */ __name((resource, minimumVersion, printMessage) => exports.ox_lib.checkDependency(resource, minimumVersion, printMessage), "checkDependency");
    }
  });

  // node_modules/@overextended/ox_lib/dist/common/index.js
  var init_common = __esm({
    "node_modules/@overextended/ox_lib/dist/common/index.js"() {
      init_locale();
      init_version();
      init_misc();
    }
  });

  // common/vehicles.ts
  function GetTopVehicleStats(category) {
    return category ? vehicleStats[category] : vehicleStats;
  }
  function GetVehicleData(filter) {
    if (!filter) return vehicles;
    if (typeof filter === "string") return vehicles[filter];
    if (Array.isArray(filter)) {
      const obj = {};
      filter.forEach((name) => {
        const vehicle = vehicles[name];
        if (vehicle) obj[name] = vehicle;
      });
      return obj;
    }
  }
  function GetVehicleNetworkType(modelName) {
    const vehicleType = vehicles[modelName]?.type;
    switch (vehicleType) {
      case "bicycle":
        return "bike";
      case "blimp":
        return "heli";
      case "quadbike":
      case "amphibious_quadbike":
      case "amphibious_automobile":
      case "submarinecar":
        return "automobile";
      default:
        return vehicleType;
    }
  }
  var vehicles, vehicleStats;
  var init_vehicles = __esm({
    "common/vehicles.ts"() {
      init_common2();
      vehicles = LoadDataFile("vehicles");
      vehicleStats = LoadDataFile("vehicleStats");
      __name(GetTopVehicleStats, "GetTopVehicleStats");
      __name(GetVehicleData, "GetVehicleData");
      __name(GetVehicleNetworkType, "GetVehicleNetworkType");
      exports("GetTopVehicleStats", GetTopVehicleStats);
      exports("GetVehicleData", GetVehicleData);
      exports("GetVehicleNetworkType", GetVehicleNetworkType);
    }
  });

  // common/index.ts
  function LoadDataFile(file) {
    return JSON.parse(LoadResourceFile("ox_core", `/common/data/${file}.json`));
  }
  function GetGroupPermissions(groupName) {
    return GlobalState[`group.${groupName}:permissions`] || {};
  }
  var init_common2 = __esm({
    "common/index.ts"() {
      init_common();
      init_vehicles();
      if (!checkDependency("ox_lib", "3.24.0", true)) throw new Error("Failed dependency check.");
      __name(LoadDataFile, "LoadDataFile");
      __name(GetGroupPermissions, "GetGroupPermissions");
      console.info = (...args) => console.log(`^3${args.join("	")}^0`);
      exports("GetGroupPermissions", GetGroupPermissions);
    }
  });

  // node_modules/@overextended/ox_lib/dist/client/callback/index.js
  function onServerCallback(eventName, cb) {
    exports.ox_lib.setValidCallback(eventName, true);
    onNet(`__ox_cb_${eventName}`, async (resource, key, ...args) => {
      let response;
      try {
        response = await cb(...args);
      } catch (e) {
        console.error(`an error occurred while handling callback event ${eventName}`);
        console.log(`^3${e.stack}^0`);
      }
      emitNet(`__ox_cb_${resource}`, key, response);
    });
  }
  var pendingCallbacks, callbackTimeout;
  var init_callback = __esm({
    "node_modules/@overextended/ox_lib/dist/client/callback/index.js"() {
      init_cache();
      pendingCallbacks = {};
      callbackTimeout = GetConvarInt("ox:callbackTimeout", 3e5);
      onNet(`__ox_cb_${cache.resource}`, (key, ...args) => {
        if (!source) return;
        const resolve = pendingCallbacks[key];
        if (!resolve) return;
        delete pendingCallbacks[key];
        resolve(...args);
      });
      __name(onServerCallback, "onServerCallback");
    }
  });

  // node_modules/@overextended/ox_lib/dist/client/streaming/index.js
  function streamingRequest(request, hasLoaded, assetType, asset, timeout = 3e4, ...args) {
    if (hasLoaded(asset)) return asset;
    request(asset, ...args);
    return waitFor(() => {
      if (hasLoaded(asset)) return asset;
    }, `failed to load ${assetType} '${asset}' - this may be caused by
- too many loaded assets
- oversized, invalid, or corrupted assets`, timeout);
  }
  var requestAnimDict, requestModel;
  var init_streaming = __esm({
    "node_modules/@overextended/ox_lib/dist/client/streaming/index.js"() {
      init_misc();
      __name(streamingRequest, "streamingRequest");
      requestAnimDict = /* @__PURE__ */ __name((animDict, timeout) => {
        if (!DoesAnimDictExist(animDict)) throw new Error(`attempted to load invalid animDict '${animDict}'`);
        return streamingRequest(RequestAnimDict, HasAnimDictLoaded, "animDict", animDict, timeout);
      }, "requestAnimDict");
      requestModel = /* @__PURE__ */ __name((model, timeout) => {
        if (typeof model !== "number") model = GetHashKey(model);
        if (!IsModelValid(model)) throw new Error(`attempted to load invalid model '${model}'`);
        return streamingRequest(RequestModel, HasModelLoaded, "model", model, timeout);
      }, "requestModel");
    }
  });

  // node_modules/@overextended/ox_lib/dist/client/interface/input.js
  var inputDialog;
  var init_input = __esm({
    "node_modules/@overextended/ox_lib/dist/client/interface/input.js"() {
      inputDialog = /* @__PURE__ */ __name(async (heading, rows, options) => await exports.ox_lib.inputDialog(heading, rows, options), "inputDialog");
    }
  });

  // node_modules/@overextended/ox_lib/dist/client/interface/notify.js
  var notify;
  var init_notify = __esm({
    "node_modules/@overextended/ox_lib/dist/client/interface/notify.js"() {
      notify = /* @__PURE__ */ __name((data) => exports.ox_lib.notify(data), "notify");
    }
  });

  // node_modules/@overextended/ox_lib/dist/client/index.js
  var init_client = __esm({
    "node_modules/@overextended/ox_lib/dist/client/index.js"() {
      init_cache();
      init_misc();
      init_callback();
      init_streaming();
      init_input();
      init_notify();
    }
  });

  // client/vehicle/parser.ts
  var parser_exports = {};
  function GetVehicleModels(parseAll) {
    return GetAllVehicleModels().filter((vehicle) => parseAll || !vehicles2[vehicle]).sort();
  }
  async function IsModelValid2(hash) {
    try {
      await requestModel(hash, 1e4);
      return true;
    } catch {
      return false;
    }
  }
  function SpawnVehicle(hash, coords) {
    const entity = CreateVehicle(hash, ...coords, 0, false, false);
    SetPedIntoVehicle(cache.ped, entity, -1);
    return entity;
  }
  function GetVehicleTypeEx(entity) {
    switch (GetVehicleTypeRaw(entity)) {
      case 0:
      default:
        return "automobile";
      case 1:
        return "plane";
      case 2:
        return "trailer";
      case 3:
        return "quadbike";
      case 5:
        return "submarinecar";
      case 6:
        return "amphibious_automobile";
      case 7:
        return "amphibious_quadbike";
      case 8:
        return "heli";
      case 9:
        return "blimp";
      case 11:
        return "bike";
      case 12:
        return "bicycle";
      case 13:
        return "boat";
      case 14:
        return "train";
      case 15:
        return "submarine";
    }
  }
  function ParseVehicleData(entity, hash, model) {
    let make = GetMakeNameFromVehicleModel(hash);
    if (!make) make = GetMakeNameFromVehicleModel(model.replace(/\W/g, "")) || "";
    const vehicleType = GetVehicleTypeEx(entity);
    const vehicleCategory = vehicleType === "heli" || vehicleType === "plane" || vehicleType === "blimp" ? "air" : vehicleType === "boat" || vehicleType === "submarine" ? "sea" : "land";
    const data = {
      acceleration: +GetVehicleModelAcceleration(hash).toFixed(4),
      braking: +GetVehicleModelMaxBraking(hash).toFixed(4),
      handling: +GetVehicleModelEstimatedAgility(hash).toFixed(4),
      speed: +GetVehicleModelEstimatedMaxSpeed(hash).toFixed(4),
      traction: +GetVehicleModelMaxTraction(hash).toFixed(4),
      name: GetLabelText(GetDisplayNameFromVehicleModel(hash)),
      make: make ? GetLabelText(make) : "",
      class: GetVehicleClass(entity),
      seats: GetVehicleModelNumberOfSeats(hash),
      doors: GetNumberOfVehicleDoors(entity),
      type: vehicleType,
      price: 0,
      category: vehicleCategory
    };
    if (DoesVehicleHaveWeapons(entity)) data.weapons = true;
    CalculateVehiclePrice(data, entity);
    console.log(`^5Parsed valid model ${model} (${data.make || "?"} ${data.name})^0`);
    return data;
  }
  function CalculateVehiclePrice(data, entity) {
    let price = data.braking + data.acceleration + data.handling + data.speed;
    if (GetVehicleHasKers(entity)) price *= 2;
    if (GetHasRocketBoost(entity)) price *= 3;
    if (GetCanVehicleJump(entity)) price *= 1.5;
    if (GetVehicleHasParachute(entity)) price *= 1.5;
    if (data.weapons) price *= 5;
    data.price = Math.floor(price * (PRICE_WEIGHTS[data.type] ?? 1));
  }
  function CleanupVehicle(entity, coords) {
    SetVehicleAsNoLongerNeeded(entity);
    SetModelAsNoLongerNeeded(GetEntityModel(entity));
    DeleteEntity(entity);
    SetEntityCoordsNoOffset(cache.ped, ...coords, false, false, false);
  }
  var PRICE_WEIGHTS, BATCH_SIZE, vehicles2;
  var init_parser = __esm({
    "client/vehicle/parser.ts"() {
      init_client();
      init_vehicles();
      PRICE_WEIGHTS = {
        automobile: 1600,
        bicycle: 150,
        bike: 500,
        boat: 6e3,
        heli: 9e4,
        plane: 16e3,
        quadbike: 1100,
        train: 6e3,
        submarinecar: 26e3,
        submarine: 22e3,
        blimp: 14e3,
        trailer: 1e4,
        amphibious_automobile: 6400,
        amphibious_quadbike: 4600
      };
      BATCH_SIZE = 10;
      vehicles2 = GetVehicleData();
      __name(GetVehicleModels, "GetVehicleModels");
      __name(IsModelValid2, "IsModelValid");
      __name(SpawnVehicle, "SpawnVehicle");
      __name(GetVehicleTypeEx, "GetVehicleTypeEx");
      __name(ParseVehicleData, "ParseVehicleData");
      __name(CalculateVehiclePrice, "CalculateVehiclePrice");
      __name(CleanupVehicle, "CleanupVehicle");
      on("ox:setVehicleData", (model, data) => {
        if (!vehicles2[model]) console.error(`Cannot set vehicle data for ${model} (invalid model)`);
        Object.assign(vehicles2[model], data);
      });
      onServerCallback("ox:generateVehicleData", async (parseAll) => {
        const coords = GetEntityCoords(cache.ped, true);
        const invalidVehicles = [];
        const vehicleModels = GetVehicleModels(parseAll);
        SetPlayerControl(cache.playerId, false, 1 << 8);
        FreezeEntityPosition(cache.ped, true);
        notify({ title: "Generating vehicle data", description: `${vehicleModels.length} models loaded.`, type: "inform" });
        let parsed = 0;
        for (let i = 0; i < vehicleModels.length; i += BATCH_SIZE) {
          await Promise.all(
            vehicleModels.slice(i, i + BATCH_SIZE).map(async (model) => {
              model = model.toLowerCase();
              const hash = GetHashKey(model);
              const isValid = await IsModelValid2(hash);
              if (!isValid) return invalidVehicles.push(model);
              try {
                const entity = SpawnVehicle(hash, coords);
                vehicles2[model] = ParseVehicleData(entity, hash, model);
                emit(`ox:parsedVehicle`, model, entity);
                ++parsed;
                CleanupVehicle(entity, coords);
              } catch {
                invalidVehicles.push(model);
              }
            })
          );
        }
        SetPlayerControl(cache.playerId, true, 0);
        FreezeEntityPosition(cache.ped, false);
        notify({
          title: "Generated vehicle data",
          description: `Generated data for ${parsed}/${vehicleModels.length} models.`,
          type: "success"
        });
        console.log(`^5Generated data for ${parsed}/${vehicleModels.length} models.^0`);
        if (invalidVehicles.length)
          console.log(
            `^3Failed to parse data for ${invalidVehicles.length} invalid vehicles.
${JSON.stringify(invalidVehicles, null, 2)}^0`
          );
        await sleep(5e3);
        return [vehicles2, GetTopVehicleStats(), invalidVehicles];
      });
    }
  });

  // client/index.ts
  init_common2();

  // common/config.ts
  var SV_LAN = GetConvarInt("sv_lan", 0) === 1;
  var CHARACTER_SLOTS = GetConvarInt("ox:characterSlots", 1);
  var PLATE_PATTERN = GetConvar("ox:plateFormat", "........").toUpperCase();
  var DEFAULT_VEHICLE_STORE = GetConvar("ox:defaultVehicleStore", "impound");
  var DEBUG = (() => {
    return SV_LAN || GetConvarInt("ox:debug", 0) === 1;
  })();

  // client/config.ts
  var DEATH_SYSTEM = GetConvarInt("ox:deathSystem", 1) === 1;
  var CHARACTER_SELECT = GetConvarInt("ox:characterSelect", 1) === 1;
  var SPAWN_LOCATION = JSON.parse(GetConvar("ox:spawnLocation", "[-258.211, -293.077, 21.6132, 206.0]"));
  var HOSPITAL_BLIPS = GetConvarInt("ox:hospitalBlips", 1) === 1;

  // client/utils.ts
  function netEvent(event, fn) {
    onNet(event, (...args) => {
      if (source !== "") fn(...args);
    });
  }
  __name(netEvent, "netEvent");

  // client/player/index.ts
  init_common2();

  // client/player/status.ts
  function UpdateStatuses() {
    for (const name in Statuses) {
      const status = Statuses[name];
      if (!status?.onTick) continue;
      const curValue = OxPlayer.getStatus(name) ?? status.default;
      const newValue = curValue + status.onTick;
      OxPlayer.setStatus(name, newValue < 0 ? 0 : newValue > 100 ? 100 : Number.parseFloat(newValue.toPrecision(8)));
    }
    emit("ox:statusTick", OxPlayer.getStatuses());
    emitNet("ox:updateStatuses", OxPlayer.getStatuses());
  }
  __name(UpdateStatuses, "UpdateStatuses");
  on("ox:playerLoaded", () => {
    const id = setInterval(() => {
      if (!OxPlayer.isLoaded) return clearInterval(id);
      UpdateStatuses();
    }, 1e3);
  });

  // client/player/index.ts
  var Statuses = {};
  var callableMethods = {};
  var PlayerSingleton = class {
    static {
      __name(this, "PlayerSingleton");
    }
    userId;
    charId;
    stateId;
    #isLoaded;
    #groups;
    #statuses;
    #metadata;
    #state;
    constructor() {
      this.#isLoaded = false;
      this.#groups = {};
      this.#statuses = {};
      this.#metadata = {};
      this.#state = LocalPlayer.state;
      Object.entries(Object.getOwnPropertyDescriptors(this.constructor.prototype)).reduce(
        (methods, [name, desc]) => {
          if (name !== "constructor" && desc.writable && typeof desc.value === "function") methods[name] = true;
          return methods;
        },
        callableMethods
      );
      netEvent("ox:startCharacterSelect", (userId) => {
        this.userId = userId;
        for (const key in this.#groups) delete this.#groups[key];
        for (const key in this.#metadata) delete this.#metadata[key];
      });
      netEvent("ox:setActiveCharacter", async (character, groups) => {
        OxPlayer.charId = character.charId;
        OxPlayer.stateId = character.stateId;
        for (const key in groups) this.#groups[key] = groups[key];
      });
      netEvent("ox:setPlayerData", (key, value) => {
        if (!this.charId) return;
        this.#metadata[key] = value;
        emit(`ox:player:${key}`, value);
      });
      netEvent("ox:setPlayerStatus", (key, value, set) => {
        if (set) {
          Statuses[key] = GlobalState[`status.${key}`];
        }
        this.#statuses[key] = value;
      });
      netEvent("ox:setGroup", (name, grade) => {
        this.#groups[name] = grade;
      });
      exports("GetPlayer", () => this);
      exports("GetPlayerCalls", () => callableMethods);
      exports("CallPlayer", (method, ...args) => {
        const fn = this[method];
        if (!fn) return console.error(`cannot call method ${method} (method does not exist)`);
        if (!callableMethods[method]) return console.error(`cannot call method ${method} (method is not exported)`);
        return fn.bind(this)(...args);
      });
    }
    get isLoaded() {
      return this.#isLoaded;
    }
    set isLoaded(state) {
      this.#isLoaded = state;
    }
    get state() {
      return this.#state;
    }
    get(key) {
      if (!key) return OxPlayer;
      return this.#metadata[key];
    }
    getGroup(filter) {
      if (typeof filter === "string") {
        return this.#groups[filter];
      }
      if (Array.isArray(filter)) {
        for (const name of filter) {
          const grade = this.#groups[name];
          if (grade) return [name, grade];
        }
      } else if (typeof filter === "object") {
        for (const [name, requiredGrade] of Object.entries(filter)) {
          const grade = this.#groups[name];
          if (grade && requiredGrade <= grade) {
            return [name, grade];
          }
        }
      }
    }
    getGroupByType(type) {
      const groupNames = GlobalState.groups;
      const groups = groupNames.reduce((acc, groupName) => {
        const group = GlobalState[`group.${groupName}`];
        if (group.type === type) acc.push(groupName);
        return acc;
      }, []);
      return this.getGroup(groups);
    }
    getGroups() {
      return this.#groups;
    }
    getStatus(name) {
      return this.#statuses[name];
    }
    getStatuses() {
      return this.#statuses;
    }
    setStatus(name, value) {
      if (this.#statuses[name] === void 0) return false;
      this.#statuses[name] = value < 0 ? 0 : value > 100 ? 100 : Number.parseFloat(value.toPrecision(8));
      return true;
    }
    addStatus(name, value) {
      if (this.#statuses[name] === void 0) return false;
      const newValue = this.#statuses[name] + value;
      this.#statuses[name] = newValue < 0 ? 0 : newValue > 100 ? 100 : Number.parseFloat(newValue.toPrecision(8));
      return true;
    }
    removeStatus(name, value) {
      if (this.#statuses[name] === void 0) return false;
      const newValue = this.#statuses[name] - value;
      this.#statuses[name] = newValue < 0 ? 0 : newValue > 100 ? 100 : Number.parseFloat(newValue.toPrecision(8));
      return true;
    }
    hasPermission(permission) {
      const matchResult = permission.match(/^group\.([^.]+)\.(.*)/);
      const groupName = matchResult?.[1];
      permission = matchResult?.[2] ?? permission;
      if (groupName) {
        const grade = this.#groups[groupName];
        if (!grade) return false;
        const permissions = GetGroupPermissions(groupName);
        for (let g = grade; g > 0; g--) {
          const value = permissions[g] && permissions[g][permission];
          if (value !== void 0) return value;
        }
      }
      return false;
    }
  };
  var OxPlayer = new PlayerSingleton();

  // client/spawn.ts
  init_common();
  init_client();

  // common/locales.ts
  init_common();
  var locales_default = /* @__PURE__ */ __name((str, ...args) => locale(str, ...args), "default");

  // client/spawn.ts
  DoScreenFadeOut(0);
  NetworkStartSoloTutorialSession();
  setTimeout(() => emitNet("ox:playerJoined"));
  async function StartSession() {
    if (IsPlayerSwitchInProgress()) {
      StopPlayerSwitch();
    }
    if (GetIsLoadingScreenActive()) {
      SendLoadingScreenMessage('{"fullyLoaded": true}');
      ShutdownLoadingScreenNui();
    }
    NetworkStartSoloTutorialSession();
    DoScreenFadeOut(0);
    ShutdownLoadingScreen();
    SetPlayerControl(cache.playerId, false, 0);
    SetPlayerInvincible(cache.playerId, true);
    while (!OxPlayer.isLoaded) {
      DisableAllControlActions(0);
      ThefeedHideThisFrame();
      HideHudAndRadarThisFrame();
      await sleep(0);
    }
    NetworkEndTutorialSession();
    SetPlayerControl(cache.playerId, true, 0);
    SetPlayerInvincible(cache.playerId, false);
    SetMaxWantedLevel(0);
    NetworkSetFriendlyFireOption(true);
    SetPlayerHealthRechargeMultiplier(cache.playerId, 0);
  }
  __name(StartSession, "StartSession");
  netEvent("ox:startCharacterSelect", async (_userId, characters) => {
    if (OxPlayer.isLoaded) {
      OxPlayer.isLoaded = false;
      emit("ox:playerLogout");
    }
    StartSession();
    if (!CHARACTER_SELECT) return;
    const character = characters[0];
    const [x, y, z] = [
      character?.x || SPAWN_LOCATION[0],
      character?.y || SPAWN_LOCATION[1],
      character?.z || SPAWN_LOCATION[2]
    ];
    const heading = character?.heading || SPAWN_LOCATION[3];
    RequestCollisionAtCoord(x, y, z);
    FreezeEntityPosition(cache.ped, true);
    SetEntityCoordsNoOffset(cache.ped, x, y, z, true, true, false);
    SetEntityHeading(cache.ped, heading);
    SwitchOutPlayer(cache.ped, 1 | 8192, 1);
    while (GetPlayerSwitchState() !== 5) await sleep(0);
    DoScreenFadeIn(200);
    if (character) {
      return emitNet("ox:setActiveCharacter", character.charId);
    }
    const input = await inputDialog(
      locales_default("create_character"),
      [
        {
          type: "input",
          required: true,
          icon: "user-pen",
          label: locales_default("firstname"),
          placeholder: "John"
        },
        {
          type: "input",
          required: true,
          icon: "user-pen",
          label: locales_default("lastname"),
          placeholder: "Smith"
        },
        {
          type: "select",
          required: true,
          icon: "circle-user",
          label: locales_default("gender"),
          options: [
            {
              label: locales_default("male"),
              value: "male"
            },
            {
              label: locales_default("female"),
              value: "female"
            },
            {
              label: locales_default("non_binary"),
              value: "non_binary"
            }
          ]
        },
        {
          type: "date",
          required: true,
          icon: "calendar-days",
          label: locales_default("date_of_birth"),
          format: "YYYY-MM-DD",
          min: "1900-01-01",
          max: "2006-01-01",
          default: "2006-01-01"
        }
      ],
      {
        allowCancel: false
      }
    );
    if (!input) return;
    emitNet("ox:setActiveCharacter", {
      firstName: input[0],
      lastName: input[1],
      gender: input[2],
      date: input[3]
    });
  });
  netEvent("ox:setActiveCharacter", async (character) => {
    if (CHARACTER_SELECT) {
      SwitchInPlayer(PlayerPedId());
      SetGameplayCamRelativeHeading(0);
    }
    await waitFor(() => IsScreenFadedIn() && !IsPlayerSwitchInProgress() ? true : void 0, "", 0);
    SetEntityHealth(cache.ped, character.health ?? GetEntityMaxHealth(cache.ped));
    SetPedArmour(cache.ped, character.armour ?? 0);
    FreezeEntityPosition(cache.ped, false);
    OxPlayer.isLoaded = true;
    emit("playerSpawned");
    emit("ox:playerLoaded", OxPlayer, character.isNew);
  });

  // client/death.ts
  init_client();

  // node_modules/@nativewrappers/fivem/common/utils/ClassTypes.js
  var ClassTypes = /* @__PURE__ */ ((ClassTypes2) => {
    ClassTypes2[ClassTypes2["Ped"] = 0] = "Ped";
    ClassTypes2[ClassTypes2["Prop"] = 1] = "Prop";
    ClassTypes2[ClassTypes2["Vehicle"] = 2] = "Vehicle";
    ClassTypes2[ClassTypes2["Entity"] = 3] = "Entity";
    ClassTypes2[ClassTypes2["Player"] = 4] = "Player";
    ClassTypes2[ClassTypes2["Vector2"] = 5] = "Vector2";
    ClassTypes2[ClassTypes2["Vector3"] = 6] = "Vector3";
    ClassTypes2[ClassTypes2["Vector4"] = 7] = "Vector4";
    ClassTypes2[ClassTypes2["Quanterion"] = 8] = "Quanterion";
    return ClassTypes2;
  })(ClassTypes || {});

  // node_modules/@nativewrappers/fivem/common/utils/Vector.js
  var __defProp2 = Object.defineProperty;
  var __name2 = /* @__PURE__ */ __name((target, value) => __defProp2(target, "name", { value, configurable: true }), "__name");
  var EXT_VECTOR2 = 20;
  var EXT_VECTOR3 = 21;
  var EXT_VECTOR4 = 22;
  var size = Symbol("size");
  var Vector = class _Vector {
    static {
      __name(this, "Vector");
    }
    static {
      __name2(this, "Vector");
    }
    static create(x, y = x, z, w) {
      if (typeof x === "object") ({ x, y, z, w } = x);
      const size2 = this instanceof _Vector && this.size || [x, y, z, w].filter((arg) => arg !== void 0).length;
      switch (size2) {
        case 1:
        case 2:
          return new Vector2(x, y);
        case 3:
          return new Vector3(x, y, z);
        case 4:
          return new Vector4(x, y, z, w);
        default:
          throw new Error(`Cannot instantiate Vector with size of ${size2}.`);
      }
    }
    /**
     * Creates a deep copy of the provided vector.
     * @param obj The vector to clone.
     * @returns A new vector instance that is a copy of the provided vector.
     */
    static clone(obj) {
      return this.create(obj);
    }
    /**
     * Creates a vector from binary data in a MsgpackBuffer.
     * @param msgpackBuffer The buffer containing binary data.
     * @returns A new vector instance.
     */
    static fromBuffer({ buffer, type }) {
      if (type !== EXT_VECTOR2 && type !== EXT_VECTOR3 && type !== EXT_VECTOR4)
        throw new Error("Buffer type is not a valid Vector.");
      const arr = new Array(buffer.length / 4);
      for (let i = 0; i < arr.length; i++) arr[i] = Number(buffer.readFloatLE(i * 4).toPrecision(7));
      return this.fromArray(arr);
    }
    /**
     * Performs an operation between a vector and either another vector or scalar value.
     * @param a - The first vector.
     * @param b - The second vector or scalar value.
     * @param operator - The function defining the operation to perform.
     * @returns A new vector resulting from the operation.
     */
    static operate(a, b, operator) {
      let { x, y, z, w } = a;
      const isNumber = typeof b === "number";
      x = operator(x, isNumber ? b : b.x ?? 0);
      y = operator(y, isNumber ? b : b.y ?? 0);
      if (z !== void 0) z = operator(z, isNumber ? b : b.z ?? 0);
      if (w !== void 0) w = operator(w, isNumber ? b : b.w ?? 0);
      return this.create(x, y, z, w);
    }
    /**
     * Adds two vectors or a scalar value to a vector.
     * @param a - The first vector or scalar value.
     * @param b - The second vector or scalar value.
     * @returns A new vector with incremented components.
     */
    static add(a, b) {
      return this.operate(a, b, (x, y) => x + y);
    }
    /**
     * Adds a scalar value to the x-component of a vector.
     * @param obj - The vector.
     * @param x - The value to add to the x-component.
     * @returns A new vector with the x-component incremented.
     */
    static addX(obj, x) {
      return this.create(obj.x + x, obj.y, obj.z, obj.w);
    }
    /**
     * Adds a scalar value to the y-component of a vector.
     * @param obj - The vector.
     * @param y - The value to add to the y-component.
     * @returns A new vector with the y-component incremented.
     */
    static addY(obj, y) {
      return this.create(obj.x, obj.y + y, obj.z, obj.w);
    }
    /**
     * Adds a scalar value to the z-component of a vector.
     * @param obj - The vector.
     * @param z - The value to add to the z-component.
     * @returns A new vector with the z-component incremented.
     */
    static addZ(obj, z) {
      return this.create(obj.x, obj.y, obj.z + z, obj.w);
    }
    /**
     * Adds a scalar value to the w-component of a vector.
     * @param obj - The vector.
     * @param w - The value to add to the w-component.
     * @returns A new vector with the w-component incremented.
     */
    static addW(obj, w) {
      return this.create(obj.x, obj.y, obj.z, obj.w + w);
    }
    /**
     * Subtracts one vector from another or subtracts a scalar value from a vector.
     * @param a - The vector.
     * @param b - The second vector or scalar value.
     * @returns A new vector with subtracted components.
     */
    static subtract(a, b) {
      return this.operate(a, b, (x, y) => x - y);
    }
    /**
     * Multiplies two vectors by their components, or multiplies a vector by a scalar value.
     * @param a - The vector.
     * @param b - The second vector or scalar value.
     * @returns A new vector with multiplied components.
     */
    static multiply(a, b) {
      return this.operate(a, b, (x, y) => x * y);
    }
    /**
     * Divides two vectors by their components, or divides a vector by a scalar value.
     * @param a - The vector.
     * @param b - The second vector or scalar vector.
     * @returns A new vector with divided components.
     */
    static divide(a, b) {
      return this.operate(a, b, (x, y) => x / y);
    }
    /**
     * Performs an operation between a vector and either another vector or scalar value converting the vector into absolute values.
     * @param a - The first vector.
     * @param b - The second vector or scalar value.
     * @param operator - The function defining the operation to perform.
     * @returns A new vector resulting from the operation.
     */
    static operateAbsolute(a, b, operator) {
      let { x, y, z, w } = a;
      const isNumber = typeof b === "number";
      x = operator(Math.abs(x), isNumber ? b : Math.abs(b.x ?? 0));
      y = operator(Math.abs(y), isNumber ? b : Math.abs(b.y ?? 0));
      if (z !== void 0) z = operator(Math.abs(z), isNumber ? b : Math.abs(b.z ?? 0));
      if (w !== void 0) w = operator(Math.abs(w), isNumber ? b : Math.abs(b.w ?? 0));
      return this.create(x, y, z, w);
    }
    /**
     * Adds two vectors or a scalar value to a vector.
     * @param a - The first vector or scalar value.
     * @param b - The second vector or scalar value.
     * @returns A new vector with incremented components.
     */
    static addAbsolute(a, b) {
      return this.operateAbsolute(a, b, (x, y) => x + y);
    }
    /**
     * Subtracts one vector from another or subtracts a scalar value from a vector.
     * @param a - The vector.
     * @param b - The second vector or scalar value.
     * @returns A new vector with subtracted components.
     */
    static subtractAbsolute(a, b) {
      return this.operateAbsolute(a, b, (x, y) => x - y);
    }
    /**
     * Multiplies two vectors by their components, or multiplies a vector by a scalar value.
     * @param a - The vector.
     * @param b - The second vector or scalar value.
     * @returns A new vector with multiplied components.
     */
    static multiplyAbsolute(a, b) {
      return this.operateAbsolute(a, b, (x, y) => x * y);
    }
    /**
     * Divides two vectors by their components, or divides a vector by a scalar value
     * @param a - The vector.
     * @param b - The second vector or scalar vector.
     * @returns A new vector with divided components.
     */
    static divideAbsolute(a, b) {
      return this.operateAbsolute(a, b, (x, y) => x / y);
    }
    /**
     * Calculates the dot product of two vectors.
     * @param a - The first vector.
     * @param b - The second vector.
     * @returns A scalar value representing the degree of alignment between the input vectors.
     */
    static dotProduct(a, b) {
      let result = 0;
      for (const key of ["x", "y", "z", "w"]) {
        const x = a[key];
        const y = b[key];
        if (!!x && !!y) result += x * y;
        else if (x || y) throw new Error("Vectors must have the same dimensions.");
      }
      return result;
    }
    /**
     * Calculates the cross product of two vectors in three-dimensional space.
     * @param a - The first vector.
     * @param b - The second vector.
     * @returns A new vector perpendicular to both input vectors.
     */
    static crossProduct(a, b) {
      const { x: ax, y: ay, z: az, w: aw } = a;
      const { x: bx, y: by, z: bz } = b;
      if (ax === void 0 || ay === void 0 || az === void 0 || bx === void 0 || by === void 0 || bz === void 0)
        throw new Error("Vector.crossProduct requires two three-dimensional vectors.");
      return this.create(ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx, aw);
    }
    /**
     * Normalizes a vector, producing a new vector with the same direction but with a magnitude of 1.
     * @param vector - The vector to be normalized.
     * @returns The new normalized vector.
     */
    static normalize(a) {
      const length = a instanceof _Vector ? a.Length : this.Length(a);
      return this.divide(a, length);
    }
    /**
     * Creates a vector from an array of numbers.
     * @param primitive An array of numbers (usually returned by a native).
     */
    static fromArray(primitive) {
      const [x, y, z, w] = primitive;
      return this.create(x, y, z, w);
    }
    /**
     * Creates a vector from an array or object containing vector components.
     * @param primitive The object to use as a vector.
     */
    static fromObject(primitive) {
      if (Array.isArray(primitive)) return this.fromArray(primitive);
      if ("buffer" in primitive) return this.fromBuffer(primitive);
      const { x, y, z, w } = primitive;
      return this.create(x, y, z, w);
    }
    /**
     * Creates an array of vectors from an array of number arrays
     * @param primitives A multi-dimensional array of number arrays
     */
    static fromArrays(primitives) {
      return primitives.map(this.fromArray);
    }
    /**
     * Calculates the length (magnitude) of a vector.
     * @param obj - The vector for which to calculate the length.
     * @returns The magnitude of the vector.
     */
    static Length(obj) {
      let sum = 0;
      for (const key of ["x", "y", "z", "w"]) {
        if (key in obj) {
          const value = obj[key];
          sum += value * value;
        }
      }
      return Math.sqrt(sum);
    }
    type;
    [size] = 2;
    x = 0;
    y = 0;
    z;
    w;
    /**
     * Constructs a new vector.
     * @param x The x-component of the vector.
     * @param y The y-component of the vector (optional, defaults to x).
     * @param z The z-component of the vector (optional).
     * @param w The w-component of the vector (optional).
     */
    constructor(x, y = x, z, w) {
      for (let i = 0; i < arguments.length; i++) {
        if (typeof arguments[i] !== "number") {
          throw new TypeError(
            `${this.constructor.name} argument at index ${i} must be a number, but got ${typeof arguments[i]}`
          );
        }
      }
      this.x = x;
      this.y = y;
    }
    *[Symbol.iterator]() {
      yield this.x;
      yield this.y;
      if (this.z !== void 0) yield this.z;
      if (this.w !== void 0) yield this.w;
    }
    get size() {
      return this[size];
    }
    toString() {
      return `vector${this.size}(${this.toArray().join(", ")})`;
    }
    /**
     * @see Vector.clone
     */
    clone() {
      return _Vector.clone(this);
    }
    /**
     * The product of the Euclidean magnitudes of this and another Vector.
     *
     * @param v Vector to find Euclidean magnitude between.
     * @returns Euclidean magnitude with another vector.
     */
    distanceSquared(v) {
      const w = this.subtract(v);
      return _Vector.dotProduct(w, w);
    }
    /**
     * The distance between two Vectors.
     *
     * @param v Vector to find distance between.
     * @returns Distance between this and another vector.
     */
    distance(v) {
      return Math.sqrt(this.distanceSquared(v));
    }
    /**
     * @see Vector.normalize
     */
    normalize() {
      return _Vector.normalize(this);
    }
    /**
     * @see Vector.dotProduct
     */
    dotProduct(v) {
      return _Vector.dotProduct(this, v);
    }
    /**
     * @see Vector.add
     */
    add(v) {
      return _Vector.add(this, v);
    }
    /**
     * @see Vector.addX
     */
    addX(x) {
      return _Vector.addX(this, x);
    }
    /**
     * @see Vector.addY
     */
    addY(y) {
      return _Vector.addY(this, y);
    }
    /**
     * @see Vector.subtract
     */
    subtract(v) {
      return _Vector.subtract(this, v);
    }
    /**
     * @see Vector.multiply
     */
    multiply(v) {
      return _Vector.multiply(this, v);
    }
    /**
     * @see Vector.divide
     */
    divide(v) {
      return _Vector.divide(this, v);
    }
    /**
     * @see Vector.addAbsolute
     */
    addAbsolute(v) {
      return _Vector.addAbsolute(this, v);
    }
    /**
     * @see Vector.subtractAbsolute
     */
    subtractAbsolute(v) {
      return _Vector.subtractAbsolute(this, v);
    }
    /**
     * @see Vector.multiply
     */
    multiplyAbsolute(v) {
      return _Vector.multiplyAbsolute(this, v);
    }
    /**
     * @see Vector.divide
     */
    divideAbsolute(v) {
      return _Vector.divideAbsolute(this, v);
    }
    /**
     * Converts the vector to an array of its components.
     */
    toArray() {
      return [...this];
    }
    /**
     * Replaces the components of the vector with the components of another vector object.
     * @param v - The object whose components will replace the current vector's components.
     */
    replace(v) {
      for (const key of ["x", "y", "z", "w"]) {
        if (key in this && key in v) this[key] = v[key];
      }
    }
    /**
     * Calculates the length (magnitude) of a vector.
     * @returns The magnitude of the vector.
     */
    get Length() {
      let sum = 0;
      for (const value of this) sum += value * value;
      return Math.sqrt(sum);
    }
    swizzle(components) {
      if (!/^[xyzw]+$/.test(components)) throw new Error(`Invalid key in swizzle components (${components}).`);
      const arr = components.split("").map((char) => this[char] ?? 0);
      return _Vector.create(...arr);
    }
  };
  var Vector2 = class _Vector2 extends Vector {
    static {
      __name(this, "Vector2");
    }
    static {
      __name2(this, "Vector2");
    }
    // DO NOT USE, ONLY EXPOSED BECAUSE TS IS TRASH, THIS TYPE IS NOT GUARANTEED
    // TO EXIST, CHANGING IT WILL BREAK STUFF
    type = ClassTypes.Vector2;
    [size] = 2;
    static Zero = new _Vector2(0, 0);
    /**
     * Constructs a new 2D vector.
     * @param x The x-component of the vector.
     * @param y The y-component of the vector (optional, defaults to x).
     */
    constructor(x, y = x) {
      super(x, y);
    }
    /**
     * Creates a new vector based on the provided parameters.
     * @param x The x-component of the vector.
     * @param y The y-component of the vector (optional, defaults to the value of x).
     * @returns A new vector instance.
     */
    static create(x, y = x) {
      if (typeof x === "object") ({ x, y } = x);
      return new this(x, y);
    }
  };
  var Vector3 = class _Vector3 extends Vector {
    static {
      __name(this, "Vector3");
    }
    static {
      __name2(this, "Vector3");
    }
    // DO NOT USE, ONLY EXPOSED BECAUSE TS IS TRASH, THIS TYPE IS NOT GUARANTEED
    // TO EXIST, CHANGING IT WILL BREAK STUFF
    type = ClassTypes.Vector3;
    [size] = 3;
    z = 0;
    static Zero = new _Vector3(0, 0, 0);
    static UnitX = new _Vector3(1, 0, 0);
    static UnitY = new _Vector3(0, 1, 0);
    static UnitZ = new _Vector3(0, 0, 1);
    static One = new _Vector3(1, 1, 1);
    static Up = new _Vector3(0, 0, 1);
    static Down = new _Vector3(0, 0, -1);
    static Left = new _Vector3(-1, 0, 0);
    static Right = new _Vector3(1, 0, 0);
    static ForwardRH = new _Vector3(0, 1, 0);
    static ForwardLH = new _Vector3(0, -1, 0);
    static BackwardRH = new _Vector3(0, -1, 0);
    static BackwardLH = new _Vector3(0, 1, 0);
    static Backward = _Vector3.BackwardRH;
    /**
     * Constructs a new 3D vector.
     * @param x The x-component of the vector.
     * @param y The y-component of the vector (optional, defaults to x).
     * @param z The z-component of the vector (optional, defaults to y).
     */
    constructor(x, y = x, z = y) {
      super(x, y, z);
      this.z = z;
    }
    /**
     * Creates a new vector based on the provided parameters.
     * @param x The x-component of the vector.
     * @param y The y-component of the vector (optional, defaults to the value of x).
     * @param z The z-component of the vector (optional, defaults to the value of y).
     * @returns A new vector instance.
     */
    static create(x, y = x, z = y) {
      if (typeof x === "object") ({ x, y, z = y } = x);
      return new this(x, y, z);
    }
    /**
     * @see Vector.addZ
     */
    addZ(z) {
      return Vector.addZ(this, z);
    }
    /**
     * @see Vector.crossProduct
     */
    crossProduct(v) {
      return Vector.crossProduct(this, v);
    }
    /**
     * @returns the x and y values as Vec2
     */
    toVec2() {
      return new Vector2(this.x, this.y);
    }
  };
  var Vector4 = class _Vector4 extends Vector {
    static {
      __name(this, "Vector4");
    }
    static {
      __name2(this, "Vector4");
    }
    // DO NOT USE, ONLY EXPOSED BECAUSE TS IS TRASH, THIS TYPE IS NOT GUARANTEED
    // TO EXIST, CHANGING IT WILL BREAK STUFF
    type = ClassTypes.Vector4;
    [size] = 4;
    z = 0;
    w = 0;
    static Zero = new _Vector4(0, 0, 0, 0);
    /**
     * Constructs a new 4D vector.
     * @param x The x-component of the vector.
     * @param y The y-component of the vector (optional, defaults to x).
     * @param z The z-component of the vector (optional, defaults to y).
     * @param w The w-component of the vector (optional, defaults to z).
     */
    constructor(x, y = x, z = y, w = z) {
      super(x, y, z, w);
      this.z = z;
      this.w = w;
    }
    /**
     * Creates a new vector based on the provided parameters.
     * @param x The x-component of the vector.
     * @param y The y-component of the vector (optional, defaults to the value of x).
     * @param z The z-component of the vector (optional, defaults to the value of y).
     * @param w The w-component of the vector (optional, defaults to the value of z).
     * @returns A new vector instance.
     */
    static create(x, y = x, z = y, w = z) {
      if (typeof x === "object") ({ x, y, z = y, w = z } = x);
      return new this(x, y, z, w);
    }
    /**
     * @see Vector.addZ
     */
    addZ(z) {
      return Vector.addZ(this, z);
    }
    /**
     * @see Vector.addW
     */
    addW(w) {
      return Vector.addW(this, w);
    }
    /**
     * @see Vector.crossProduct
     */
    crossProduct(v) {
      return Vector.crossProduct(this, v);
    }
    /**
     * @returns the x and y values as Vec2
     */
    toVec2() {
      return new Vector2(this.x, this.y);
    }
    /**
     * @returns the x and y values as Vec3
     */
    toVec3() {
      return new Vector3(this.x, this.y, this.z);
    }
  };

  // client/death.ts
  init_common2();
  var hospitals = LoadDataFile("hospitals").map((vec) => {
    const hospital = Vector4.fromArray(vec);
    if (HOSPITAL_BLIPS) {
      const blip = AddBlipForCoord(hospital.x, hospital.y, hospital.z);
      SetBlipSprite(blip, 61);
      SetBlipDisplay(blip, 8);
      SetBlipScale(blip, 0.8);
      SetBlipColour(blip, 35);
      SetBlipAsShortRange(blip, true);
    }
    return hospital;
  });
  var anims = [
    ["missfinale_c1@", "lying_dead_player0"],
    ["veh@low@front_ps@idle_duck", "sit"],
    ["dead", "dead_a"]
  ];
  var playerIsDead = false;
  async function ClearDeath(tickId, bleedOut) {
    const anim = cache.vehicle ? anims[1] : anims[0];
    clearTick(tickId);
    if (bleedOut) {
      const coords = Vector3.fromArray(GetEntityCoords(cache.ped, true));
      let distance = 1e3;
      const hospital = hospitals.reduce((closest, hospital2) => {
        const hospitalDistance = coords.distance(hospital2);
        if (hospitalDistance > distance) return closest;
        distance = hospitalDistance;
        return hospital2;
      });
      DoScreenFadeOut(500);
      RequestCollisionAtCoord(hospital.x, hospital.y, hospital.z);
      while (!IsScreenFadedOut()) await sleep(0);
      StopAnimTask(cache.ped, anim[0], anim[1], 8);
      SetEntityCoordsNoOffset(cache.ped, hospital.x, hospital.y, hospital.z, false, false, false);
      SetEntityHeading(cache.ped, hospital.w);
      SetGameplayCamRelativeHeading(0);
      await sleep(500);
      DoScreenFadeIn(500);
      while (!IsScreenFadedIn()) await sleep(0);
    } else {
      StopAnimTask(cache.ped, anim[0], anim[1], 8);
    }
    ClearPedBloodDamage(cache.ped);
    SetPlayerControl(cache.playerId, false, 0);
    SetEveryoneIgnorePlayer(cache.playerId, false);
    SetPlayerControl(cache.playerId, true, 0);
    SetPlayerInvincible(cache.playerId, false);
    for (let index = 0; index < anims.length; index++) RemoveAnimDict(anims[index][0]);
    emit("ox:playerRevived");
  }
  __name(ClearDeath, "ClearDeath");
  var bleedOutTime = DEBUG ? 100 : 1e3;
  async function OnPlayerDeath() {
    emitNet("ox:playerDeath");
    emit("ox_inventory:disarm");
    emit("ox:playerDeath");
    if (!DEATH_SYSTEM) return;
    for (let index = 0; index < anims.length; index++) await requestAnimDict(anims[index][0]);
    ShakeGameplayCam("DEATH_FAIL_IN_EFFECT_SHAKE", 1);
    let bleedOut = 0;
    const tickId = setTick(() => {
      const anim = cache.vehicle ? anims[1] : anims[0];
      if (!IsEntityPlayingAnim(cache.ped, anim[0], anim[1], 3))
        TaskPlayAnim(cache.ped, anim[0], anim[1], 50, 8, -1, 1, 1, false, false, false);
      DisableFirstPersonCamThisFrame();
      bleedOut++;
      if (bleedOut > bleedOutTime) ClearDeath(tickId, true);
    });
    const coords = GetEntityCoords(cache.ped, true);
    const health = Math.floor(Math.max(100, GetEntityMaxHealth(cache.ped) * 0.8));
    NetworkResurrectLocalPlayer(coords[0], coords[1], coords[2], GetEntityHeading(cache.ped), 0, false);
    if (cache.vehicle) SetPedIntoVehicle(cache.ped, cache.vehicle, cache.seat);
    SetEntityInvincible(cache.ped, true);
    SetEntityHealth(cache.ped, health);
    SetEveryoneIgnorePlayer(cache.playerId, true);
  }
  __name(OnPlayerDeath, "OnPlayerDeath");
  AddStateBagChangeHandler("isDead", `player:${cache.serverId}`, async (_bagName, _key, value) => {
    playerIsDead = value;
  });
  function ResetDeathState() {
    emitNet("ox:playerRevived");
  }
  __name(ResetDeathState, "ResetDeathState");
  on("ox:playerLogout", ResetDeathState);
  on("ox:playerRevived", ResetDeathState);
  on("ox:playerLoaded", () => {
    const id = setInterval(() => {
      if (!OxPlayer.isLoaded) return clearInterval(id);
      if (!playerIsDead && IsPedDeadOrDying(PlayerPedId(), true)) OnPlayerDeath();
    }, 200);
  });

  // client/vehicle/index.ts
  init_client();
  if (DEBUG) Promise.resolve().then(() => init_parser());
  onServerCallback("ox:getNearbyVehicles", (radius) => {
    const nearbyEntities = [];
    const playerCoords = Vector3.fromArray(GetEntityCoords(cache.ped, true));
    GetGamePool("CVehicle").forEach((entityId) => {
      const coords = Vector3.fromArray(GetEntityCoords(entityId, true));
      const distance = coords.distance(playerCoords);
      if (distance <= (radius ?? 2) && NetworkGetEntityIsNetworked(entityId)) nearbyEntities.push(VehToNet(entityId));
    });
    return nearbyEntities;
  });

  // client/index.ts
  for (let i = 0; i < GetNumberOfVehicleNumberPlates(); i++) {
    SetDefaultVehicleNumberPlateTextPattern(i, PLATE_PATTERN);
  }
})();

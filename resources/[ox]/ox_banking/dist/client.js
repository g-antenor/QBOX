(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __name = (target, value) => __defProp(target, "name", { value, configurable: true });
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

  // node_modules/@overextended/ox_lib/shared/resource/cache/index.js
  var cacheEvents = {};
  var cache = new Proxy({
    resource: GetCurrentResourceName(),
    game: GetGameName()
  }, {
    get(target, key) {
      const result = key ? target[key] : target;
      if (result !== void 0)
        return result;
      cacheEvents[key] = [];
      AddEventHandler(`ox_lib:cache:${key}`, (value) => {
        const oldValue = target[key];
        const events = cacheEvents[key];
        events.forEach((cb) => cb(value, oldValue));
        target[key] = value;
      });
      target[key] = exports.ox_lib.cache(key) || false;
      return target[key];
    }
  });

  // node_modules/@overextended/ox_lib/shared/resource/locale/index.js
  var import_fast_printf = __toESM(require_printf());
  var dict = {};
  function flattenDict(source2, target, prefix) {
    for (const key in source2) {
      const fullKey = prefix ? `${prefix}.${key}` : key;
      const value = source2[key];
      if (typeof value === "object")
        flattenDict(value, target, fullKey);
      else
        target[fullKey] = String(value);
    }
    return target;
  }
  __name(flattenDict, "flattenDict");
  var locale = /* @__PURE__ */ __name((str, ...args) => {
    const lstr = dict[str];
    if (!lstr)
      return str;
    if (lstr) {
      if (typeof lstr !== "string")
        return lstr;
      if (args.length > 0) {
        return (0, import_fast_printf.printf)(lstr, ...args);
      }
      return lstr;
    }
    return str;
  }, "locale");
  var getLocales = /* @__PURE__ */ __name(() => dict, "getLocales");
  function loadLocale(key) {
    const data = LoadResourceFile(cache.resource, `locales/${key}.json`);
    if (!data)
      console.warn(`could not load 'locales/${key}.json'`);
    return JSON.parse(data) || {};
  }
  __name(loadLocale, "loadLocale");
  var initLocale = /* @__PURE__ */ __name((key) => {
    const lang = key || exports.ox_lib.getLocaleKey();
    let locales = loadLocale("en");
    if (lang !== "en")
      Object.assign(locales, loadLocale(lang));
    const flattened = flattenDict(locales, {});
    for (let [k, v] of Object.entries(flattened)) {
      if (typeof v === "string") {
        const regExp = new RegExp(/\$\{([^}]+)\}/g);
        const matches = v.match(regExp);
        if (matches) {
          for (const match of matches) {
            if (!match)
              break;
            const variable = match.substring(2, match.length - 1);
            let locale2 = flattened[variable];
            if (locale2) {
              v = v.replace(match, locale2);
            }
          }
        }
      }
      dict[k] = v;
    }
  }, "initLocale");
  initLocale();

  // node_modules/@overextended/ox_lib/shared/index.js
  var context = IsDuplicityVersion() ? "server" : "client";
  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms, null));
  }
  __name(sleep, "sleep");
  async function waitFor(cb, errMessage, timeout) {
    let value = await cb();
    if (value !== void 0)
      return value;
    if (timeout || timeout == null) {
      if (typeof timeout !== "number")
        timeout = 1e3;
    }
    const start = GetGameTimer();
    let id;
    const p = new Promise((resolve, reject) => {
      id = setTick(async () => {
        const elapsed = timeout && GetGameTimer() - start;
        if (elapsed && elapsed > timeout) {
          return reject(`${errMessage || "failed to resolve callback"} (waited ${elapsed}ms)`);
        }
        value = await cb();
        if (value !== void 0)
          resolve(value);
      });
    }).finally(() => clearTick(id));
    return p;
  }
  __name(waitFor, "waitFor");

  // src/common/locales/index.ts
  var Locale = /* @__PURE__ */ __name((str, ...args) => locale(str, ...args), "Locale");

  // src/common/index.ts
  function LoadFile(path) {
    return LoadResourceFile(cache.resource, path);
  }
  __name(LoadFile, "LoadFile");
  function LoadJsonFile(path) {
    return JSON.parse(LoadFile(path));
  }
  __name(LoadJsonFile, "LoadJsonFile");
  var Config = LoadJsonFile("data/config.json");

  // node_modules/@overextended/ox_lib/client/resource/interface/textui.js
  var hideTextUI = /* @__PURE__ */ __name(() => exports.ox_lib.hideTextUI(), "hideTextUI");

  // node_modules/@overextended/ox_lib/client/resource/streaming/index.js
  function streamingRequest(request, hasLoaded, assetType, asset, timeout = 3e4, ...args) {
    if (hasLoaded(asset))
      return asset;
    request(asset, ...args);
    return waitFor(() => {
      if (hasLoaded(asset))
        return asset;
    }, `failed to load ${assetType} '${asset}' - this may be caused by
- too many loaded assets
- oversized, invalid, or corrupted assets`, timeout);
  }
  __name(streamingRequest, "streamingRequest");
  var requestAnimDict = /* @__PURE__ */ __name((animDict, timeout) => {
    if (!DoesAnimDictExist(animDict))
      throw new Error(`attempted to load invalid animDict '${animDict}'`);
    return streamingRequest(RequestAnimDict, HasAnimDictLoaded, "animDict", animDict, timeout);
  }, "requestAnimDict");

  // node_modules/@overextended/ox_lib/client/resource/cache/index.js
  cache.playerId = PlayerId();
  cache.serverId = GetPlayerServerId(cache.playerId);

  // node_modules/@overextended/ox_lib/client/resource/callback/index.js
  var pendingCallbacks = {};
  var callbackTimeout = GetConvarInt("ox:callbackTimeout", 3e5);
  onNet(`__ox_cb_${cache.resource}`, (key, ...args) => {
    if (!source)
      return;
    const resolve = pendingCallbacks[key];
    if (!resolve)
      return;
    delete pendingCallbacks[key];
    resolve(...args);
  });
  var eventTimers = {};
  function eventTimer(eventName, delay) {
    if (delay && delay > 0) {
      const currentTime = GetGameTimer();
      if ((eventTimers[eventName] || 0) > currentTime)
        return false;
      eventTimers[eventName] = currentTime + delay;
    }
    return true;
  }
  __name(eventTimer, "eventTimer");
  function triggerServerCallback(eventName, delay, ...args) {
    if (!eventTimer(eventName, delay))
      return;
    let key;
    do {
      key = `${eventName}:${Math.floor(Math.random() * (1e5 + 1))}`;
    } while (pendingCallbacks[key]);
    emitNet(`ox_lib:validateCallback`, eventName, cache.resource, key);
    emitNet(`__ox_cb_${eventName}`, cache.resource, key, ...args);
    return new Promise((resolve, reject) => {
      pendingCallbacks[key] = (args2) => {
        if (Array.isArray(args2) && args2[0] === "cb_invalid")
          reject(`callback '${eventName} does not exist`);
        resolve(args2);
      };
      setTimeout(reject, callbackTimeout, `callback event '${key}' timed out`);
    });
  }
  __name(triggerServerCallback, "triggerServerCallback");

  // src/client/utils.ts
  var serverNuiCallback = /* @__PURE__ */ __name((event) => {
    RegisterNuiCallback(event, async (data, cb) => {
      const response = await triggerServerCallback(`ox_banking:${event}`, null, data);
      cb(response);
    });
  }, "serverNuiCallback");
  function SendTypedNUIMessage(action, data) {
    SendNUIMessage({
      action,
      data
    });
  }
  __name(SendTypedNUIMessage, "SendTypedNUIMessage");

  // src/client/index.ts
  var hasLoadedUi = false;
  var isUiOpen = false;
  var isATMopen = false;
  function canOpenUi() {
    return IsPedOnFoot(cache.ped) && !IsPedDeadOrDying(cache.ped, true);
  }
  __name(canOpenUi, "canOpenUi");
  function setupUi() {
    if (hasLoadedUi) return;
    const accountRoles = GlobalState.accountRoles;
    const permissions = accountRoles.reduce(
      (acc, role) => {
        acc[role] = GlobalState[`accountRole.${role}`];
        return acc;
      },
      {}
    );
    SendNUIMessage({
      action: "setInitData",
      data: {
        locales: getLocales(),
        permissions
      }
    });
    hasLoadedUi = true;
  }
  __name(setupUi, "setupUi");
  var openAtm = /* @__PURE__ */ __name(async ({ entity }) => {
    if (!canOpenUi) return;
    const atmEnter = await requestAnimDict("mini@atmenter");
    const [cX, cY, cZ] = GetEntityCoords(entity, false);
    const [pX, pY, pZ] = GetEntityCoords(cache.ped, false);
    const doAnim = entity && DoesEntityExist(entity) && Math.abs(cX - cY + (cZ - pX) + (pY - pZ)) < 5;
    if (doAnim) {
      const [x, y, z] = GetOffsetFromEntityInWorldCoords(entity, 0, -0.7, 1);
      const heading = GetEntityHeading(entity);
      const sequence = OpenSequenceTask(0);
      TaskGoStraightToCoord(0, x, y, z, 1, 5e3, heading, 0.25);
      TaskPlayAnim(0, atmEnter, "enter", 4, -2, 1600, 0, 0, false, false, false);
      CloseSequenceTask(sequence);
      TaskPerformSequence(cache.ped, sequence);
      ClearSequenceTask(sequence);
    }
    setupUi();
    await sleep(0);
    await waitFor(() => GetSequenceProgress(cache.ped) === -1 || void 0, "", false);
    PlaySoundFrontend(-1, "PIN_BUTTON", "ATM_SOUNDS", true);
    isUiOpen = true;
    isATMopen = true;
    SendTypedNUIMessage("openATM", null);
    SetNuiFocus(true, true);
    RemoveAnimDict(atmEnter);
  }, "openAtm");
  exports("openAtm", openAtm);
  var openBank = /* @__PURE__ */ __name(() => {
    if (!canOpenUi) return;
    setupUi();
    const playerCash = exports.ox_inventory.GetItemCount("money");
    isUiOpen = true;
    hideTextUI();
    SendTypedNUIMessage("openBank", { cash: playerCash });
    SetNuiFocus(true, true);
  }, "openBank");
  exports("openBank", openBank);
  AddTextEntry("ox_banking_bank", Locale("bank"));
  var createBankBlip = /* @__PURE__ */ __name(([x, y, z]) => {
    const { sprite, colour, scale } = Config.BankBlip;
    if (!sprite) return;
    const blip = AddBlipForCoord(x, y, z);
    SetBlipSprite(blip, sprite);
    SetBlipColour(blip, colour);
    SetBlipScale(blip, scale);
    SetBlipAsShortRange(blip, true);
    BeginTextCommandSetBlipName("ox_banking_bank");
    EndTextCommandSetBlipName(blip);
  }, "createBankBlip");
  var banks = LoadJsonFile("data/banks.json");
  if (Config.UseOxTarget) {
    const atms = LoadJsonFile("data/atms.json").map((value) => GetHashKey(value));
    const atmOptions = {
      name: "access_atm",
      icon: "fa-solid fa-money-check",
      label: Locale("target_access_atm"),
      export: "openAtm",
      distance: 1.3
    };
    const bankOptions = {
      name: "access_bank",
      icon: "fa-solid fa-dollar-sign",
      label: Locale("target_access_bank"),
      export: "openBank",
      distance: 1.3
    };
    exports.ox_target.addModel(atms, atmOptions);
    banks.forEach((bank) => {
      exports.ox_target.addBoxZone({
        coords: bank.coords,
        size: bank.size,
        rotation: bank.rotation,
        drawSprite: true,
        options: bankOptions
      });
      createBankBlip(bank.coords);
    });
  } else banks.forEach(({ coords }) => createBankBlip(coords));
  RegisterNuiCallback("exit", async (_, cb) => {
    cb(1);
    SetNuiFocus(false, false);
    isUiOpen = false;
    isATMopen = false;
  });
  on("ox_inventory:itemCount", (itemName, count) => {
    if (!isUiOpen || isATMopen || itemName !== "money") return;
    SendTypedNUIMessage("refreshCharacter", { cash: count });
  });
  serverNuiCallback("getDashboardData");
  serverNuiCallback("transferOwnership");
  serverNuiCallback("manageUser");
  serverNuiCallback("removeUser");
  serverNuiCallback("getAccountUsers");
  serverNuiCallback("addUserToAccount");
  serverNuiCallback("getAccounts");
  serverNuiCallback("createAccount");
  serverNuiCallback("deleteAccount");
  serverNuiCallback("depositMoney");
  serverNuiCallback("withdrawMoney");
  serverNuiCallback("transferMoney");
  serverNuiCallback("renameAccount");
  serverNuiCallback("convertAccountToShared");
  serverNuiCallback("getLogs");
  serverNuiCallback("getInvoices");
  serverNuiCallback("payInvoice");
})();

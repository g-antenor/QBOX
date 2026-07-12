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

// node_modules/@overextended/oxmysql/MySQL.js
var require_MySQL = __commonJS({
  "node_modules/@overextended/oxmysql/MySQL.js"(exports2) {
    "use strict";
    Object.defineProperty(exports2, "__esModule", { value: true });
    exports2.oxmysql = void 0;
    var QueryStore = [];
    function assert(condition, message) {
      if (!condition)
        throw new TypeError(message);
    }
    __name(assert, "assert");
    var safeArgs = /* @__PURE__ */ __name((query, params, cb, transaction) => {
      if (typeof query === "number") {
        query = QueryStore[query];
        assert(typeof query === "string", "First argument received invalid query store reference");
      }
      if (transaction) {
        assert(typeof query === "object", `First argument expected object, recieved ${typeof query}`);
      } else {
        assert(typeof query === "string", `First argument expected string, received ${typeof query}`);
      }
      if (params) {
        const paramType = typeof params;
        assert(paramType === "object" || paramType === "function", `Second argument expected object or function, received ${paramType}`);
        if (!cb && paramType === "function") {
          cb = params;
          params = void 0;
        }
      }
      if (cb !== void 0)
        assert(typeof cb === "function", `Third argument expected function, received ${typeof cb}`);
      return [query, params, cb];
    }, "safeArgs");
    var exp = global.exports.oxmysql;
    var currentResourceName = GetCurrentResourceName();
    function execute(method, query, params) {
      return new Promise((resolve, reject) => {
        exp[method](query, params, (result, error) => {
          if (error)
            return reject(error);
          resolve(result);
        }, currentResourceName, true);
      });
    }
    __name(execute, "execute");
    exports2.oxmysql = {
      store(query) {
        assert(typeof query !== "string", `Query expects a string, received ${typeof query}`);
        return QueryStore.push(query);
      },
      ready(callback) {
        setImmediate(async () => {
          while (GetResourceState("oxmysql") !== "started")
            await new Promise((resolve) => setTimeout(resolve, 50, null));
          callback();
        });
      },
      async query(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb);
        const result = await execute("query", query, params);
        return cb ? cb(result) : result;
      },
      async single(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb);
        const result = await execute("single", query, params);
        return cb ? cb(result) : result;
      },
      async scalar(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb);
        const result = await execute("scalar", query, params);
        return cb ? cb(result) : result;
      },
      async update(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb);
        const result = await execute("update", query, params);
        return cb ? cb(result) : result;
      },
      async insert(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb);
        const result = await execute("insert", query, params);
        return cb ? cb(result) : result;
      },
      async prepare(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb);
        const result = await execute("prepare", query, params);
        return cb ? cb(result) : result;
      },
      async rawExecute(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb);
        const result = await execute("rawExecute", query, params);
        return cb ? cb(result) : result;
      },
      async transaction(query, params, cb) {
        [query, params, cb] = safeArgs(query, params, cb, true);
        const result = await execute("transaction", query, params);
        return cb ? cb(result) : result;
      },
      isReady() {
        return exp.isReady();
      },
      async awaitConnection() {
        return await exp.awaitConnection();
      },
      async startTransaction(cb) {
        return exp.startTransaction(cb, currentResourceName);
      }
    };
  }
});

// node_modules/@overextended/ox_core/package/lib/index.js
var Ox = exports.ox_core;

// node_modules/@overextended/ox_core/package/lib/server/account.js
var _AccountInterface = class _AccountInterface {
  accountId;
  constructor(accountId) {
    this.accountId = accountId;
  }
};
__name(_AccountInterface, "AccountInterface");
var AccountInterface = _AccountInterface;
Object.keys(exports.ox_core.GetAccountCalls()).forEach((method) => {
  AccountInterface.prototype[method] = function(...args) {
    return exports.ox_core.CallAccount(this.accountId, method, ...args);
  };
});
AccountInterface.prototype.toString = function() {
  return JSON.stringify(this, null, 2);
};
function CreateAccountInstance(account) {
  if (!account)
    return;
  return new AccountInterface(account.accountId);
}
__name(CreateAccountInstance, "CreateAccountInstance");
async function GetAccount(accountId) {
  const account = await exports.ox_core.GetAccount(accountId);
  return CreateAccountInstance(account);
}
__name(GetAccount, "GetAccount");
async function GetCharacterAccount(charId) {
  const account = await exports.ox_core.GetCharacterAccount(charId);
  return CreateAccountInstance(account);
}
__name(GetCharacterAccount, "GetCharacterAccount");
async function CreateAccount(owner, label) {
  const account = await exports.ox_core.CreateAccount(owner, label);
  return CreateAccountInstance(account);
}
__name(CreateAccount, "CreateAccount");

// node_modules/@overextended/ox_core/package/lib/server/player.js
var _PlayerInterface = class _PlayerInterface {
  source;
  userId;
  charId;
  stateId;
  username;
  identifier;
  ped;
  state;
  constructor(source2, userId, charId, stateId, username, identifier, ped) {
    this.source = source2;
    this.userId = userId;
    this.charId = charId;
    this.stateId = stateId;
    this.username = username;
    this.identifier = identifier;
    this.ped = ped;
    this.source = source2;
    this.userId = userId;
    this.charId = charId;
    this.stateId = stateId;
    this.username = username;
    this.identifier = identifier;
    this.ped = ped;
  }
  getCoords() {
    return GetEntityCoords(this.ped);
  }
  getState() {
    return Player(source).state;
  }
  async getAccount() {
    return this.charId ? GetCharacterAccount(this.charId) : null;
  }
};
__name(_PlayerInterface, "PlayerInterface");
var PlayerInterface = _PlayerInterface;
Object.keys(exports.ox_core.GetPlayerCalls()).forEach((method) => {
  PlayerInterface.prototype[method] = function(...args) {
    return exports.ox_core.CallPlayer(this.source, method, ...args);
  };
});
PlayerInterface.prototype.toString = function() {
  return JSON.stringify(this, null, 2);
};
function CreatePlayerInstance(player) {
  if (!player)
    return;
  return new PlayerInterface(player.source, player.userId, player.charId, player.stateId, player.username, player.identifier, player.ped);
}
__name(CreatePlayerInstance, "CreatePlayerInstance");
function GetPlayer(playerId) {
  return CreatePlayerInstance(exports.ox_core.GetPlayer(playerId));
}
__name(GetPlayer, "GetPlayer");

// node_modules/@overextended/ox_core/package/lib/server/vehicle.js
var _VehicleInterface = class _VehicleInterface {
  entity;
  netId;
  script;
  plate;
  model;
  make;
  id;
  vin;
  owner;
  group;
  constructor(entity, netId, script, plate, model, make, id, vin, owner, group) {
    this.entity = entity;
    this.netId = netId;
    this.script = script;
    this.plate = plate;
    this.model = model;
    this.make = make;
    this.id = id;
    this.vin = vin;
    this.owner = owner;
    this.group = group;
    this.entity = entity;
    this.netId = netId;
    this.script = script;
    this.plate = plate;
    this.model = model;
    this.make = make;
    this.id = id;
    this.vin = vin;
    this.owner = owner;
    this.group = group;
  }
  getCoords() {
    return this.entity ? GetEntityCoords(this.entity) : null;
  }
  getState() {
    return this.entity ? Entity(this.entity).state : null;
  }
};
__name(_VehicleInterface, "VehicleInterface");
var VehicleInterface = _VehicleInterface;
Object.keys(exports.ox_core.GetVehicleCalls()).forEach((method) => {
  VehicleInterface.prototype[method] = function(...args) {
    return exports.ox_core.CallVehicle(this.vin, method, ...args);
  };
});
VehicleInterface.prototype.toString = function() {
  return JSON.stringify(this, null, 2);
};

// node_modules/@overextended/ox_lib/shared/resource/version/index.js
var checkDependency = /* @__PURE__ */ __name((resource, minimumVersion, printMessage) => exports.ox_lib.checkDependency(resource, minimumVersion, printMessage), "checkDependency");

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

// node_modules/@overextended/ox_lib/server/resource/callback/index.js
var pendingCallbacks = {};
var callbackTimeout = GetConvarInt("ox:callbackTimeout", 3e5);
onNet(`__ox_cb_${cache.resource}`, (key, ...args) => {
  const resolve = pendingCallbacks[key];
  if (!resolve)
    return;
  delete pendingCallbacks[key];
  resolve(...args);
});
function onClientCallback(eventName, cb) {
  exports.ox_lib.setValidCallback(eventName, true);
  onNet(`__ox_cb_${eventName}`, async (resource, key, ...args) => {
    const src = source;
    let response;
    try {
      response = await cb(src, ...args);
    } catch (e) {
      console.error(`an error occurred while handling callback event ${eventName}`);
      console.log(`^3${e.stack}^0`);
    }
    emitNet(`__ox_cb_${resource}`, src, key, response);
  });
}
__name(onClientCallback, "onClientCallback");

// node_modules/@overextended/ox_lib/server/resource/version/index.js
var versionCheck = /* @__PURE__ */ __name((repository) => exports.ox_lib.versionCheck(repository), "versionCheck");

// src/server/index.ts
var import_oxmysql = __toESM(require_MySQL(), 1);
versionCheck("overextended/ox_banking");
var coreDepCheck = checkDependency("ox_core", "1.1.0");
if (coreDepCheck !== true) {
  setInterval(() => {
    console.error(coreDepCheck[1]);
  }, 1e3);
}
onClientCallback("ox_banking:getAccounts", async (playerId) => {
  const player = GetPlayer(playerId);
  if (!player.charId) return;
  const accessAccounts = await import_oxmysql.oxmysql.rawExecute(
    `
    SELECT DISTINCT
      COALESCE(access.role, gg.accountRole) AS role,
      account.*,
      COALESCE(c.fullName, g.label) AS ownerName
    FROM
      accounts account
    LEFT JOIN characters c ON account.owner = c.charId
    LEFT JOIN ox_groups g
      ON account.group = g.name
    LEFT JOIN character_groups cg
      ON cg.charId = ?
      AND cg.name = account.group
    LEFT JOIN ox_group_grades gg
      ON account.group = gg.group
      AND cg.grade = gg.grade
    LEFT JOIN accounts_access access
      ON account.id = access.accountId
      AND access.charId = ?
    WHERE
      account.type != 'inactive'
      AND (
        access.charId = ?
        OR (
          account.group IS NOT NULL
          AND gg.accountRole IS NOT NULL
        )
      )
    GROUP BY
      account.id
    ORDER BY
      account.owner = ? DESC,
      account.isDefault DESC
    `,
    [player.charId, player.charId, player.charId, player.charId]
  );
  const accounts = accessAccounts.map((account) => ({
    group: account.group,
    id: account.id,
    label: account.label,
    isDefault: player.charId === account.owner ? account.isDefault : false,
    balance: account.balance,
    type: account.type,
    owner: account.ownerName,
    role: account.role
  }));
  return accounts;
});
onClientCallback("ox_banking:createAccount", async (playerId, { name, shared }) => {
  const { charId } = GetPlayer(playerId);
  if (!charId) return;
  const account = await CreateAccount(charId, name);
  if (shared) await account.setShared();
  return account.accountId;
});
onClientCallback("ox_banking:deleteAccount", async (playerId, accountId) => {
  const account = await GetAccount(accountId);
  const balance = await (account == null ? void 0 : account.get("balance"));
  if (balance !== 0) return;
  const hasPermission = await account.playerHasPermission(playerId, "closeAccount");
  if (!hasPermission) return;
  return await account.deleteAccount();
});
onClientCallback("ox_banking:depositMoney", async (playerId, { accountId, amount }) => {
  const account = await GetAccount(accountId);
  return await account.depositMoney(playerId, amount);
});
onClientCallback("ox_banking:withdrawMoney", async (playerId, { accountId, amount }) => {
  const account = await GetAccount(accountId);
  return await account.withdrawMoney(playerId, amount);
});
onClientCallback(
  "ox_banking:transferMoney",
  async (playerId, { fromAccountId, target, transferType, amount }) => {
    var _a, _b;
    const account = await GetAccount(fromAccountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "withdraw"));
    if (!hasPermission) return;
    target = typeof target == "string" ? Number.parseInt(target) : target;
    let targetAccountId = 0;
    try {
      targetAccountId = transferType === "account" ? (_a = await GetAccount(target)) == null ? void 0 : _a.accountId : (_b = await GetCharacterAccount(target)) == null ? void 0 : _b.accountId;
    } catch (e) {
      return {
        success: false,
        message: "account_id_not_exists"
      };
    }
    if (transferType === "person" && !targetAccountId)
      return {
        success: false,
        message: "state_id_not_exists"
      };
    if (!targetAccountId)
      return {
        success: false,
        message: "account_id_not_exists"
      };
    if (account.accountId === targetAccountId)
      return {
        success: false,
        message: "same_account_transfer"
      };
    const player = GetPlayer(playerId);
    return await account.transferBalance({
      toId: targetAccountId,
      amount,
      actorId: player.charId
    });
  }
);
onClientCallback("ox_banking:getDashboardData", async (playerId) => {
  var _a;
  const account = await ((_a = GetPlayer(playerId)) == null ? void 0 : _a.getAccount());
  if (!account) return;
  const overview = await import_oxmysql.oxmysql.rawExecute(
    `
    SELECT
      LOWER(DAYNAME(d.date)) as day,
      CAST(COALESCE(SUM(CASE WHEN at.toId = ? THEN at.amount ELSE 0 END), 0) AS UNSIGNED) as income,
      CAST(COALESCE(SUM(CASE WHEN at.fromId = ? THEN at.amount ELSE 0 END), 0) AS UNSIGNED) as expenses
    FROM (
      SELECT CURDATE() as date
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 1 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 2 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 3 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 4 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 5 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 6 DAY)
    ) d
    LEFT JOIN accounts_transactions at ON d.date = DATE(at.date) AND (at.toId = ? OR at.fromId = ?)
    GROUP BY d.date
    ORDER BY d.date ASC
    `,
    [account.accountId, account.accountId, account.accountId, account.accountId]
  );
  const transactions = await import_oxmysql.oxmysql.rawExecute(
    `
    SELECT id, amount, UNIX_TIMESTAMP(date) as date, toId, fromId, message,
    CASE
      WHEN toId = ? THEN 'inbound'
      ELSE 'outbound'
    END AS 'type'
    FROM accounts_transactions
    WHERE toId = ? OR fromId = ?
    ORDER BY id DESC
    LIMIT 5
    `,
    [account.accountId, account.accountId, account.accountId]
  );
  const invoices = await import_oxmysql.oxmysql.rawExecute(
    `
     SELECT ai.id, ai.amount, UNIX_TIMESTAMP(ai.dueDate) as dueDate, UNIX_TIMESTAMP(ai.paidAt) as paidAt, CONCAT(a.label, ' - ', IFNULL(co.fullName, g.label)) AS label,
     CASE
        WHEN ai.payerId IS NOT NULL THEN 'paid'
        WHEN NOW() > ai.dueDate THEN 'overdue'
        ELSE 'unpaid'
     END AS status
     FROM accounts_invoices ai
     LEFT JOIN accounts a ON a.id = ai.fromAccount
     LEFT JOIN characters co ON (a.owner IS NOT NULL AND co.charId = a.owner)
     LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
     WHERE ai.toAccount = ?
     ORDER BY ai.id DESC
     LIMIT 5
     `,
    [account.accountId]
  );
  return {
    balance: await account.get("balance"),
    overview,
    transactions,
    invoices
  };
});
onClientCallback(
  "ox_banking:getAccountUsers",
  async (playerId, {
    accountId,
    page,
    search
  }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "manageUser"));
    if (!hasPermission) return;
    const wildcard = sanitizeSearch(search);
    let searchStr = "";
    const accountGroup = await account.get("group");
    const queryParams = [accountId];
    if (wildcard) {
      searchStr += "AND MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE)";
      queryParams.push(wildcard);
    }
    if (accountGroup) {
      const params = [accountGroup];
      const usersQuery = `
        SELECT c.stateId, c.fullName AS name, gg.accountRole AS role FROM character_groups cg
        LEFT JOIN accounts a ON cg.name = a.group
        LEFT JOIN characters c ON c.charId = cg.charId
        LEFT JOIN ox_group_grades gg ON (cg.name = gg.group AND cg.grade = gg.grade)
        WHERE cg.name = ? ${searchStr}
        ORDER BY role DESC
        LIMIT 12
        OFFSET ?
      `;
      const countQuery = `
        SELECT COUNT(*) FROM character_groups cg
        LEFT JOIN accounts a ON cg.name = a.group
        LEFT JOIN characters c ON c.charId = cg.charId
        LEFT JOIN ox_group_grades gg ON (cg.name = gg.group AND cg.grade = gg.grade)
        WHERE cg.name = ?
      `;
      const count = await import_oxmysql.oxmysql.prepare(countQuery, params);
      if (wildcard) params.push(wildcard);
      params.push(page * 12);
      const users2 = await import_oxmysql.oxmysql.rawExecute(usersQuery, params);
      return {
        numberOfPages: count,
        users: users2
      };
    }
    const usersCount = await import_oxmysql.oxmysql.prepare(
      `SELECT COUNT(*) FROM \`accounts_access\` aa LEFT JOIN characters c ON c.charId = aa.charId WHERE accountId = ? ${searchStr}`,
      queryParams
    );
    queryParams.push(page * 12);
    const users = usersCount ? await import_oxmysql.oxmysql.rawExecute(
      `
      SELECT c.stateId, a.role, c.fullName AS \`name\` FROM \`accounts_access\` a
      LEFT JOIN \`characters\` c ON c.charId = a.charId
      WHERE a.accountId = ?
      ${searchStr}
      ORDER BY a.role DESC
      LIMIT 12
      OFFSET ?
      `,
      queryParams
    ) : [];
    return {
      numberOfPages: Math.ceil(usersCount / 12) || 1,
      users
    };
  }
);
onClientCallback(
  "ox_banking:addUserToAccount",
  async (playerId, {
    accountId,
    stateId,
    role
  }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "addUser"));
    if (!hasPermission) return false;
    const currentRole = await account.getCharacterRole(stateId);
    if (currentRole) return { success: false, message: "invalid_input" };
    return await account.setCharacterRole(stateId, role) || { success: false, message: "state_id_not_exists" };
  }
);
onClientCallback(
  "ox_banking:manageUser",
  async (playerId, {
    accountId,
    targetStateId,
    values
  }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "manageUser"));
    if (!hasPermission) return false;
    return await account.setCharacterRole(targetStateId, values.role);
  }
);
onClientCallback(
  "ox_banking:removeUser",
  async (playerId, { targetStateId, accountId }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "removeUser"));
    if (!hasPermission) return false;
    return await account.setCharacterRole(targetStateId, null);
  }
);
onClientCallback(
  "ox_banking:transferOwnership",
  async (playerId, {
    targetStateId,
    accountId
  }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "transferOwnership"));
    if (!hasPermission)
      return {
        success: false,
        message: "no_permission"
      };
    const targetCharId = await import_oxmysql.oxmysql.prepare("SELECT `charId` FROM `characters` WHERE `stateId` = ?", [
      targetStateId
    ]);
    if (!targetCharId)
      return {
        success: false,
        message: "state_id_not_exists"
      };
    const accountOwner = await account.get("owner");
    if (accountOwner === targetCharId)
      return {
        success: false,
        message: "invalid_input"
      };
    const player = GetPlayer(playerId);
    await import_oxmysql.oxmysql.prepare(
      "INSERT INTO `accounts_access` (`accountId`, `charId`, `role`) VALUES (?, ?, 'owner') ON DUPLICATE KEY UPDATE `role` = 'owner'",
      [accountId, targetCharId]
    );
    await import_oxmysql.oxmysql.prepare("UPDATE `accounts` SET `owner` = ? WHERE `id` = ?", [targetCharId, accountId]);
    await import_oxmysql.oxmysql.prepare("UPDATE `accounts_access` SET `role` = 'manager' WHERE `accountId` = ? AND `charId` = ?", [
      accountId,
      player.charId
    ]);
    return {
      success: true
    };
  }
);
onClientCallback(
  "ox_banking:renameAccount",
  async (playerId, { accountId, name }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "manageAccount"));
    if (!hasPermission) return;
    await import_oxmysql.oxmysql.prepare("UPDATE `accounts` SET `label` = ? WHERE `id` = ?", [name, accountId]);
    return true;
  }
);
onClientCallback("ox_banking:convertAccountToShared", async (playerId, { accountId }) => {
  const player = GetPlayer(playerId);
  if (!player.charId) return;
  const account = await GetAccount(accountId);
  if (!account) return;
  const { type, owner } = await account.get(["type", "owner"]);
  if (type !== "personal" || owner !== player.charId) return;
  return await account.setShared();
});
onClientCallback(
  "ox_banking:getLogs",
  async (playerId, { accountId, filters }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "viewHistory"));
    if (!hasPermission) return;
    const search = sanitizeSearch(filters.search);
    let dateSearchString = "";
    let queryParams = [accountId, accountId, accountId, accountId, accountId, accountId, accountId, accountId];
    let typeQueryString = ``;
    let queryWhere = `WHERE (at.fromId = ? OR at.toId = ?)`;
    if (search) {
      queryWhere += " AND (MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE) OR MATCH(at.message) AGAINST (? IN BOOLEAN MODE)) ";
      queryParams.push(search, search);
    }
    if (filters.type && filters.type !== "combined") {
      typeQueryString += "AND (";
      filters.type === "outbound" ? typeQueryString += "at.fromId = ?)" : typeQueryString += "at.toId = ?)";
      queryParams.push(accountId);
    }
    if (filters.date) {
      const date = getFormattedDates(filters.date);
      dateSearchString = `AND (DATE(at.date) BETWEEN ? AND ?)`;
      queryParams.push(date.from, date.to);
    }
    queryWhere += `${typeQueryString} ${dateSearchString}`;
    const countQueryParams = [...queryParams].slice(2, queryParams.length);
    queryParams.push(filters.page * 6);
    const queryData = await import_oxmysql.oxmysql.rawExecute(
      `
          SELECT
            at.id,
            at.fromId,
            at.toId,
            at.message,
            at.amount,
            CONCAT(fa.id, ' - ', IFNULL(cf.fullName, ogf.label)) AS fromAccountLabel,
            CONCAT(ta.id, ' - ', IFNULL(ct.fullName, ogt.label)) AS toAccountLabel,
            UNIX_TIMESTAMP(at.date) AS date,
            c.fullName AS name,
            CASE
              WHEN at.toId = ? THEN 'inbound'
              ELSE 'outbound'
            END AS 'type',
            CASE
                WHEN at.toId = ? THEN at.toBalance
                ELSE at.fromBalance
            END AS newBalance
          FROM accounts_transactions at
          LEFT JOIN characters c ON c.charId = at.actorId
          LEFT JOIN accounts ta ON ta.id = at.toId
          LEFT JOIN accounts fa ON fa.id = at.fromId
          LEFT JOIN characters ct ON (ta.owner IS NOT NULL AND at.fromId = ? AND ct.charId = ta.owner)
          LEFT JOIN characters cf ON (fa.owner IS NOT NULL AND at.toId = ? AND cf.charId = fa.owner)
          LEFT JOIN ox_groups ogt ON (ta.owner IS NULL AND at.fromId = ? AND ogt.name = ta.group)
          LEFT JOIN ox_groups ogf ON (fa.owner IS NULL AND at.toId = ? AND ogf.name = fa.group)
          ${queryWhere}
          ORDER BY at.id DESC
          LIMIT 6
          OFFSET ?
        `,
      queryParams
    ).catch((e) => console.log(e));
    const totalLogsCount = await import_oxmysql.oxmysql.prepare(
      `
          SELECT COUNT(*)
          FROM accounts_transactions at
          LEFT JOIN characters c ON c.charId = at.actorId
          LEFT JOIN accounts ta ON ta.id = at.toId
          LEFT JOIN accounts fa ON fa.id = at.fromId
          LEFT JOIN characters ct ON (ta.owner IS NOT NULL AND at.fromId = ? AND ct.charId = ta.owner)
          LEFT JOIN characters cf ON (fa.owner IS NOT NULL AND at.toId = ? AND cf.charId = fa.owner)
          LEFT JOIN ox_groups ogt ON (ta.owner IS NULL AND at.fromId = ? AND ogt.name = ta.group)
          LEFT JOIN ox_groups ogf ON (fa.owner IS NULL AND at.toId = ? AND ogf.name = fa.group)
          ${queryWhere}
        `,
      countQueryParams
    ).catch((e) => console.log(e));
    return {
      numberOfPages: Math.ceil(totalLogsCount / 6),
      logs: queryData
    };
  }
);
onClientCallback(
  "ox_banking:getInvoices",
  async (playerId, { accountId, filters }) => {
    const account = await GetAccount(accountId);
    const hasPermission = await (account == null ? void 0 : account.playerHasPermission(playerId, "payInvoice"));
    if (!hasPermission) return;
    const search = sanitizeSearch(filters.search);
    let queryParams = [];
    let dateSearchString = "";
    let columnSearchString = "";
    let typeSearchString = "";
    let query = "";
    let queryJoins = "";
    switch (filters.type) {
      case "unpaid":
        typeSearchString = "(ai.toAccount = ? AND ai.paidAt IS NULL)";
        queryParams.push(accountId);
        if (search) {
          columnSearchString = "AND (MATCH(a.label) AGAINST (? IN BOOLEAN MODE) OR MATCH(ai.message) AGAINST (? IN BOOLEAN MODE))";
          queryParams.push(search, search);
        }
        queryJoins = `
        LEFT JOIN accounts a ON ai.fromAccount = a.id
        LEFT JOIN characters c ON ai.actorId = c.charId
        LEFT JOIN characters co ON (a.owner IS NOT NULL AND co.charId = a.owner)
        LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
      `;
        query = `
          SELECT
            ai.id,
            c.fullName as sentBy,
            CONCAT(a.id, ' - ', IFNULL(co.fullName, g.label)) AS label,
            ai.amount,
            ai.message,
            UNIX_TIMESTAMP(ai.sentAt) AS sentAt,
            UNIX_TIMESTAMP(ai.dueDate) as dueDate,
            'unpaid' AS type
          FROM accounts_invoices ai
          ${queryJoins}
      `;
        break;
      case "paid":
        typeSearchString = "(ai.toAccount = ? AND ai.paidAt IS NOT NULL)";
        queryParams.push(accountId);
        if (search) {
          columnSearchString = `AND (MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE) OR MATCH(ai.message) AGAINST (? IN BOOLEAN MODE) OR MATCH(a.label) AGAINST (? IN BOOLEAN MODE))`;
          queryParams.push(search, search, search);
        }
        queryJoins = `
        LEFT JOIN accounts a ON ai.fromAccount = a.id
        LEFT JOIN characters c ON ai.payerId = c.charId
        LEFT JOIN characters ca ON ai.actorId = ca.charId
        LEFT JOIN characters co ON (a.owner IS NOT NULL AND co.charId = a.owner)
        LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
      `;
        query = `
        SELECT
          ai.id,
          c.fullName as paidBy,
          ca.fullName as sentBy,
          CONCAT(a.id, ' - ', IFNULL(co.fullName, g.label)) AS label,
          ai.amount,
          ai.message,
          UNIX_TIMESTAMP(ai.sentAt) AS sentAt,
          UNIX_TIMESTAMP(ai.dueDate) AS dueDate,
          UNIX_TIMESTAMP(ai.paidAt) AS paidAt,
          'paid' AS type
        FROM accounts_invoices ai
        ${queryJoins}
      `;
        break;
      case "sent":
        typeSearchString = "(ai.fromAccount = ?)";
        queryParams.push(accountId);
        if (search) {
          columnSearchString = `AND (MATCH(c.fullName) AGAINST (? IN BOOLEAN MODE) OR MATCH (ai.message) AGAINST (? IN BOOLEAN MODE) OR MATCH (a.label) AGAINST (? IN BOOLEAN MODE))`;
          queryParams.push(search, search, search);
        }
        queryJoins = `
        LEFT JOIN accounts a ON ai.toAccount = a.id
        LEFT JOIN characters c ON ai.actorId = c.charId
        LEFT JOIN characters co ON (a.owner IS NOT NULL AND co.charId = a.owner)
        LEFT JOIN ox_groups g ON (a.owner IS NULL AND g.name = a.group)
      `;
        query = `
        SELECT
          ai.id,
          c.fullName as sentBy,
          CONCAT(a.id, ' - ', IFNULL(co.fullName, g.label)) AS label,
          ai.amount,
          ai.message,
          UNIX_TIMESTAMP(ai.sentAt) AS sentAt,
          UNIX_TIMESTAMP(ai.dueDate) AS dueDate,
          CASE
            WHEN ai.payerId IS NOT NULL THEN 'paid'
            WHEN NOW() > ai.dueDate THEN 'overdue'
            ELSE 'sent'
          END AS status,
          'sent' AS type
        FROM accounts_invoices ai
        ${queryJoins}
      `;
        break;
    }
    if (filters.date) {
      const date = getFormattedDates(filters.date);
      const dateCol = filters.type === "unpaid" ? "ai.dueDate" : filters.type === "paid" ? "ai.paidAt" : "ai.sentAt";
      dateSearchString = `AND (DATE(${dateCol}) BETWEEN ? AND ?)`;
      queryParams.push(date.from, date.to);
    }
    const whereStatement = `WHERE ${typeSearchString} ${columnSearchString} ${dateSearchString}`;
    queryParams.push(filters.page * 6);
    const result = await import_oxmysql.oxmysql.rawExecute(
      `
    ${query}
    ${whereStatement}
    ORDER BY ai.id DESC
    LIMIT 6
    OFFSET ?
  `,
      queryParams
    ).catch((e) => console.log(e));
    queryParams.pop();
    const totalInvoices = await import_oxmysql.oxmysql.prepare(
      `
        SELECT COUNT(*)
        FROM accounts_invoices ai
        ${queryJoins}
        ${whereStatement}`,
      queryParams
    ).catch((e) => console.log(e));
    const numberOfPages = Math.ceil(totalInvoices / 6);
    return {
      invoices: result,
      numberOfPages
    };
  }
);
onClientCallback("ox_banking:payInvoice", async (playerId, data) => {
  const player = GetPlayer(playerId);
  if (!player.charId) return;
  return await player.payInvoice(data.invoiceId);
});
function getFormattedDates(date) {
  const rawDates = {
    from: new Date(date.from),
    to: new Date(date.to ?? date.from)
  };
  const formattedDates = {
    from: new Date(
      Date.UTC(rawDates.from.getFullYear(), rawDates.from.getMonth(), rawDates.from.getDate(), 0, 0, 0)
    ).toISOString(),
    to: new Date(
      Date.UTC(rawDates.to.getFullYear(), rawDates.to.getMonth(), rawDates.to.getDate(), 23, 59, 59)
    ).toISOString()
  };
  return formattedDates;
}
__name(getFormattedDates, "getFormattedDates");
function sanitizeSearch(search) {
  const str = [];
  search.split(/\s+/).forEach((word) => {
    str.push("+");
    str.push(word.replace(/[\p{P}\p{C}]/gu, ""));
    str.push("*");
  });
  if (str.length > 3) {
    str.splice(2, 1);
  }
  search = str.join("");
  return search === "+*" ? null : search;
}
__name(sanitizeSearch, "sanitizeSearch");

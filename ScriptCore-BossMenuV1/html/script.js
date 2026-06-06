// ScriptCore.dk - Boss Menu JS
let bossData = {};
let currentLanguage = localStorage.getItem('bossmenu_language') || 'dk';

const translations = {
    dk: {
        navDashboard: 'Oversigt', navBank: 'Økonomi', navEmployees: 'Ansatte', navRanks: 'Rangstyring', navLogs: 'Logs', navSettings: 'Indstillinger',
        latestLogs: 'Seneste Logs', seeAllLogs: 'Se alle', allLogs: 'Alle Logs', refresh: 'Opdater',
        account: 'Konto', accountSmall: 'Konto', employeesSmall: 'Ansatte', balance: 'Saldo',
        amountPlaceholder: 'Indtast beløb...', deposit: 'Indsæt', withdraw: 'Hæv',
        hireNew: 'Ansæt ny Person', serverIdPlaceholder: 'Server ID...', hirePerson: 'Ansæt Person', employeeOverview: 'Ansatte Oversigt',
        addRank: 'Tilføj rang', rankNumberPlaceholder: 'Rang nummer fx 0, 1, 2, 3...', rankNamePlaceholder: 'Rang navn fx Indsatsleder', salaryPlaceholder: 'Løn fx 4500', addRankBtn: 'Tilføj rang', ranksTitle: 'Rangs',
        settingsTitle: 'Indstillinger', language: 'Sprog', size: 'Størrelse', brightness: 'Lysstyrke', opacity: 'Gennemsigtighed',
        welcome: 'Velkommen', employees: 'Ansatte', noEmployees: 'Ingen ansatte fundet til', noRanks: 'Ingen rangs fundet til', noLogs: 'Ingen logs endnu.',
        online: 'Online', offline: 'Offline', systemName: 'Internt navn', salary: 'Løn', rank: 'Rang',
        invalidAmount: 'Indtast venligst et gyldigt beløb.', invalidServerId: 'Indtast venligst en gyldig Server ID.', invalidRank: 'Skriv et gyldigt rang nummer.', missingRankName: 'Skriv et rang navn.', confirmDeleteRank: 'Er du sikker på at du vil slette rangen', deleteRankHelp: 'Rangen bliver fjernet fra menuen.'
    },
    en: {
        navDashboard: 'Dashboard', navBank: 'Finance', navEmployees: 'Employees', navRanks: 'Rank Control', navLogs: 'Logs', navSettings: 'Settings',
        latestLogs: 'Latest Logs', seeAllLogs: 'View all', allLogs: 'All Logs', refresh: 'Refresh',
        account: 'Account', accountSmall: 'Account', employeesSmall: 'Employees', balance: 'Balance',
        amountPlaceholder: 'Enter amount...', deposit: 'Deposit', withdraw: 'Withdraw',
        hireNew: 'Hire new person', serverIdPlaceholder: 'Server ID...', hirePerson: 'Hire person', employeeOverview: 'Employee Overview',
        addRank: 'Add rank', rankNumberPlaceholder: 'Rank number e.g. 0, 1, 2, 3...', rankNamePlaceholder: 'Rank name e.g. Chief', salaryPlaceholder: 'Salary e.g. 4500', addRankBtn: 'Add rank', ranksTitle: 'Ranks',
        settingsTitle: 'Settings', language: 'Language', size: 'Size', brightness: 'Brightness', opacity: 'Opacity',
        welcome: 'Welcome', employees: 'Employees', noEmployees: 'No employees found for', noRanks: 'No ranks found for', noLogs: 'No logs yet.',
        online: 'Online', offline: 'Offline', systemName: 'Internal name', salary: 'Salary', rank: 'Rank',
        invalidAmount: 'Please enter a valid amount.', invalidServerId: 'Please enter a valid Server ID.', invalidRank: 'Enter a valid rank number.', missingRankName: 'Enter a rank name.', confirmDeleteRank: 'Are you sure you want to delete the rank', deleteRankHelp: 'The rank will be removed from the menu.'
    }
};

function t(key) {
    return (translations[currentLanguage] && translations[currentLanguage][key]) || translations.dk[key] || key;
}

function showBossToast(message, type = 'error') {
    const safeMessage = escapeHtml(message || 'Der skete en fejl.');
    let $wrap = $('#boss-toast-wrap');
    if (!$wrap.length) {
        $('body').append('<div id="boss-toast-wrap" class="boss-toast-wrap"></div>');
        $wrap = $('#boss-toast-wrap');
    }

    const $toast = $(`<div class="boss-toast ${type}">${safeMessage}</div>`);
    $wrap.append($toast);
    setTimeout(() => $toast.addClass('show'), 20);
    setTimeout(() => {
        $toast.removeClass('show');
        setTimeout(() => $toast.remove(), 220);
    }, 3500);
}

function bossConfirm(title, message, onConfirm) {
    $('#boss-confirm-overlay').remove();

    const html = `
        <div id="boss-confirm-overlay" class="boss-confirm-overlay">
            <div class="boss-confirm-box">
                <div class="boss-confirm-icon"><i class="fas fa-triangle-exclamation"></i></div>
                <h3>${escapeHtml(title || 'Bekræft')}</h3>
                <p>${escapeHtml(message || '')}</p>
                <div class="boss-confirm-actions">
                    <button class="btn btn-ghost" id="boss-confirm-cancel">Annuller</button>
                    <button class="btn btn-danger" id="boss-confirm-yes">Slet</button>
                </div>
            </div>
        </div>`;

    $('body').append(html);
    setTimeout(() => $('#boss-confirm-overlay').addClass('show'), 20);

    $('#boss-confirm-cancel').on('click', function() {
        $('#boss-confirm-overlay').removeClass('show');
        setTimeout(() => $('#boss-confirm-overlay').remove(), 180);
    });

    $('#boss-confirm-yes').on('click', function() {
        $('#boss-confirm-overlay').removeClass('show');
        setTimeout(() => $('#boss-confirm-overlay').remove(), 180);
        if (typeof onConfirm === 'function') onConfirm();
    });
}

function applyLanguage() {
    document.documentElement.lang = currentLanguage === 'dk' ? 'da' : 'en';
    $('[data-i18n]').each(function() { $(this).text(t($(this).data('i18n'))); });
    $('[data-i18n-placeholder]').each(function() { $(this).attr('placeholder', t($(this).data('i18n-placeholder'))); });
    $('#lang-dk').toggleClass('active', currentLanguage === 'dk');
    $('#lang-en').toggleClass('active', currentLanguage === 'en');
}

function setLanguage(lang) {
    currentLanguage = lang === 'en' ? 'en' : 'dk';
    localStorage.setItem('bossmenu_language', currentLanguage);
    applyLanguage();
    updateAllViews();
}

window.addEventListener('message', function(event) {
    if (event.data.action === "open") {
        bossData = normalizeBossData(event.data);
        $("body").css("display", "flex").hide().fadeIn(200);

        updateAllViews();
    }

    if (event.data.action === "refresh") {
        bossData = normalizeBossData(event.data.data || {});
        updateAllViews();
    }

    if (event.data.action === "forceClose") {
        $("body").hide();
    }
});

function normalizeBossData(data) {
    data = data || {};
    data.money = Number(data.money || 0);
    data.onlineCount = Number(data.onlineCount || 0);
    data.employees = Array.isArray(data.employees) ? data.employees : [];
    data.jobGrades = Array.isArray(data.jobGrades) ? data.jobGrades : [];
    data.logs = Array.isArray(data.logs) ? data.logs : [];
    data.jobLabel = data.jobLabel || data.jobName || "Job";
    data.gradeLabel = data.gradeLabel || "Chef";
    return data;
}

function updateAllViews() {
    updateDashboard();
    renderEmployees();
    renderRanks();
    renderLogs();
    applyLanguage();
}

function applyServerResult(result) {
    if (!result) return false;

    // Nye callbacks returnerer { ok = true, data = ... }
    if (result.data) {
        bossData = normalizeBossData(result.data);
        updateAllViews();
        return true;
    }

    // RefreshData callback returnerer selve datasættet.
    if (result.employees || result.jobGrades) {
        bossData = normalizeBossData(result);
        updateAllViews();
        return true;
    }

    if (result.error) {
        showBossToast(result.error, 'error');
    }

    return false;
}

function refreshBossData() {
    $.post(`https://${GetParentResourceName()}/refreshData`, JSON.stringify({}), function(updatedData) {
        applyServerResult(updatedData);
    });
}

function escapeHtml(value) {
    return String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function makeSafeId(value) {
    return String(value ?? "").replace(/[^a-zA-Z0-9_-]/g, "-");
}

function updateDashboard() {
    $("#welcome-user").text(t("welcome") + ", " + bossData.gradeLabel + " - " + bossData.jobLabel);
    $("#dash-money, #bank-balance").text(bossData.money.toLocaleString() + " kr.");
    $("#dash-online").text(bossData.employees.length + " " + t("employees"));
}

// Håndtering af Penge (Hæv / Indsæt)
function handleBank(type) {
    let amount = parseInt($("#bank-amount").val());
    if (isNaN(amount) || amount <= 0) {
        showBossToast(t("invalidAmount"), 'error');
        return;
    }

    $.post(`https://${GetParentResourceName()}/finance`, JSON.stringify({
        type: type,
        amount: amount
    }), function(result) {
        applyServerResult(result);
    });

    $("#bank-amount").val("");
}

// Ansæt person
function hireEmployee() {
    let serverId = parseInt($("#new-emp-id").val());
    let rankId = parseInt($("#new-emp-rank").val());

    if (isNaN(serverId) || serverId <= 0) {
        showBossToast(t("invalidServerId"), 'error');
        return;
    }

    $.post(`https://${GetParentResourceName()}/hire`, JSON.stringify({
        targetId: serverId,
        rank: rankId
    }), function(result) {
        applyServerResult(result);
    });

    $("#new-emp-id").val("");
}

function renderEmployees() {
    let html = "";

    if (!bossData.employees || bossData.employees.length === 0) {
        html = '<div class="stat-card">' + t('noEmployees') + ' ' + escapeHtml(bossData.jobLabel) + '.</div>'; 
    } else {
        bossData.employees.forEach(emp => {
            let safeId = makeSafeId(emp.id);
            let onlineBadge = emp.online ? '<small style="color:#00ff88; margin-left:6px;">' + t('online') + '</small>' : '<small style="color:#888; margin-left:6px;">' + t('offline') + '</small>'; 

            let options = "";
            bossData.jobGrades.forEach(g => {
                let sel = (parseInt(emp.grade) === parseInt(g.grade)) ? "selected" : "";
                options += `<option value="${escapeHtml(g.grade)}" ${sel}>${escapeHtml(g.label)}</option>`;
            });

            html += `
            <div class="stat-card" style="justify-content: space-between; padding: 12px; margin-bottom: 8px;">
                <div>
                    <strong>${escapeHtml(emp.name)}</strong>${onlineBadge}<br>
                    <small style="color:#aaa;">${escapeHtml(emp.gradeLabel)}</small>
                </div>
                <div style="display:flex; gap:8px; align-items:center;">
                    <select class="styled-input" style="width:130px; height:35px; font-size:12px;" id="rank-select-${safeId}">
                        ${options}
                    </select>
                    <button class="btn btn-success" style="padding: 5px 12px;" onclick="saveRank('${escapeHtml(emp.id)}')">
                        <i class="fas fa-save"></i>
                    </button>
                    <button class="btn btn-danger" style="padding: 5px 12px;" onclick="fireEmployee('${escapeHtml(emp.id)}')">
                        <i class="fas fa-user-slash"></i>
                    </button>
                </div>
            </div>`;
        });
    }

    $("#employee-list-content").html(html);

    let rankOptions = "";
    bossData.jobGrades.forEach(g => {
        rankOptions += `<option value="${escapeHtml(g.grade)}">${escapeHtml(g.label)}</option>`;
    });

    if (rankOptions === "") {
        rankOptions = '<option value="0">Ingen rangs fundet</option>';
    }

    $("#new-emp-rank").html(rankOptions);

    $("#new-emp-id").off('keypress').on('keypress', function(e) {
        if (e.which == 13) {
            hireEmployee();
        }
    });
}

function saveRank(identifier) {
    let safeId = makeSafeId(identifier);
    let newGrade = $(`#rank-select-${safeId}`).val();

    $.post(`https://${GetParentResourceName()}/changeRank`, JSON.stringify({
        targetId: identifier,
        rank: newGrade
    }), function(result) {
        applyServerResult(result);
    });
}

function fireEmployee(identifier) {
    $.post(`https://${GetParentResourceName()}/fire`, JSON.stringify({
        targetId: identifier
    }), function(result) {
        applyServerResult(result);
    });
}

function createRank() {
    let grade = parseInt($("#rank-grade").val());
    let label = ($("#rank-label").val() || "").trim();
    let salary = parseInt($("#rank-salary").val()) || 0;

    if (isNaN(grade) || grade < 0) {
        showBossToast(t("invalidRank"), 'error');
        return;
    }

    if (!label) {
        showBossToast(t("missingRankName"), 'error');
        return;
    }

    $.post(`https://${GetParentResourceName()}/createRank`, JSON.stringify({
        grade: grade,
        label: label,
        salary: salary
    }), function(result) {
        if (applyServerResult(result)) {
            $("#rank-grade").val("");
            $("#rank-label").val("");
            $("#rank-salary").val("0");
        }
    });
}

function deleteRank(grade) {
    const foundRank = (bossData.jobGrades || []).find(g => parseInt(g.grade) === parseInt(grade));
    const label = foundRank ? foundRank.label : grade;

    bossConfirm(`${t('confirmDeleteRank')} "${label}"?`, t('deleteRankHelp'), function() {
        $.post(`https://${GetParentResourceName()}/deleteRank`, JSON.stringify({
            grade: grade
        }), function(result) {
            applyServerResult(result);
        });
    });
}

function renderRanks() {
    let html = "";

    if (!bossData.jobGrades || bossData.jobGrades.length === 0) {
        html = '<div class="stat-card">' + t('noRanks') + ' ' + escapeHtml(bossData.jobLabel) + '.</div>'; 
    } else {
        bossData.jobGrades.forEach(g => {
            html += `
            <div class="stat-card" style="justify-content: space-between; gap: 12px;">
                <div>
                    <strong>${escapeHtml(g.label)}</strong><br>
                    <small>${t("systemName")}: ${escapeHtml(g.name || "-")} · ${t("salary")}: ${Number(g.salary || 0).toLocaleString()} kr.</small>
                </div>
                <div style="display:flex; align-items:center; gap:10px;">
                    <div style="font-weight:bold; color:#00ff88; min-width:70px; text-align:right;">${t("rank")} ${escapeHtml(g.grade)}</div>
                    <button class="btn btn-danger" style="padding: 6px 12px;" onclick="deleteRank(${parseInt(g.grade)})">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </div>`;
        });
    }

    $("#ranks-list-content").html(html);
}


function formatLogTime(value) {
    if (!value) return '';
    const d = new Date(String(value).replace(' ', 'T'));
    if (isNaN(d.getTime())) return escapeHtml(value);
    return d.toLocaleString(currentLanguage === 'dk' ? 'da-DK' : 'en-GB', { day:'2-digit', month:'2-digit', hour:'2-digit', minute:'2-digit' });
}

function renderLogItems(items, compact) {
    if (!items || items.length === 0) {
        return '<div class="stat-card log-empty">' + t('noLogs') + '</div>';
    }

    return items.map(log => {
        return `
        <div class="log-card ${compact ? 'small' : ''}">
            <div class="log-icon"><i class="fas fa-history"></i></div>
            <div class="log-body">
                <div class="log-title">${escapeHtml(log.message || log.action || 'Log')}</div>
                <div class="log-meta">${escapeHtml(log.actor_name || 'System')} · ${formatLogTime(log.created_at)}</div>
            </div>
        </div>`;
    }).join('');
}

function renderLogs() {
    const logs = bossData.logs || [];
    $('#dashboard-logs-content').html(renderLogItems(logs.slice(0, 4), true));
    $('#logs-list-content').html(renderLogItems(logs, false));
}

function openTab(tabId) {
    $(".tab-content").removeClass("active");
    $(".nav-link").removeClass("active");
    $("#" + tabId).addClass("active");
    $(`a[onclick="openTab('${tabId}')"]`).addClass("active");

    if (tabId === 'employees' || tabId === 'ranks' || tabId === 'logs') {
        refreshBossData();
    }
}

function closeUI() {
    $("body").fadeOut(200);
    $.post(`https://${GetParentResourceName()}/close`);
}

// System Sliders
$("#range-size").on("input", function() {
    $(".bmsc-container").css("transform", `scale(${$(this).val()})`);
    $("#size-percent").text(Math.round($(this).val() * 100) + "%");
});

$("#range-brightness").on("input", function() {
    $(".bmsc-screen").css("filter", `brightness(${$(this).val()}%)`);
    $("#brightness-percent").text($(this).val() + "%");
});

$("#range-opacity").on("input", function() {
    $(".bmsc-container").css("opacity", $(this).val());
    $("#opacity-percent").text(Math.round($(this).val() * 100) + "%");
});

function updateClock() {
    let now = new Date();
    $("#current-time").text(now.getHours().toString().padStart(2, '0') + ":" + now.getMinutes().toString().padStart(2, '0'));
}
setInterval(updateClock, 1000);
updateClock();
applyLanguage();

$(document).keyup(function(e) { if (e.key === "Escape") closeUI(); });

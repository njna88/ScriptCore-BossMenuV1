Config = {}

Config.Command = "BossMenuV1"
Config.Debug = false

-- Scriptet må kun starte hvis resource/mappen hedder dette.
-- Hvis mappen omdøbes, stopper både client og server automatisk.
Config.RequiredResourceName = "ScriptCore-BossMenuV1"

Config.TabletAnimDict = "amb@world_human_seat_wall_tablet@female@base"
Config.TabletAnimName = "base"
Config.TabletModel = "prop_cs_tablet"
Config.TabletBone = 28422

-- BossJobs styrer hvilke jobs der må bruge bossmenuen, og hvilken rang/grade der har adgang.
-- RANGS bliver IKKE oprettet i scriptet eller database.sql.
-- Selve rangene skal stadig ligge i din SQL-tabel `job_grades`.
-- bossGrade = minimum grade/rang-nummer der må åbne bossmenuen.
-- Eksempel: bossGrade = 11 betyder at grade 11 og højere har adgang.
Config.BossJobs = {
    -- Offentlige jobs
    ['police'] = { label = "POLITI", bossGrade = 11 },
    ['ambulance'] = { label = "AMBULANCE", bossGrade = 11 },
    ['brand'] = { label = "BRANDVÆSEN", bossGrade = 11 },

    -- Firmaer / virksomheder
    ['autoexotic'] = { label = "AUTOEXOTIC", bossGrade = 11 },
    ['viking'] = { label = "VIKING", bossGrade = 11 },
    ['mechanic'] = { label = "MEKANIKER", bossGrade = 11 },
    ['cardealer'] = { label = "BILFORHANDLER", bossGrade = 11 },
    ['taxi'] = { label = "TAXA", bossGrade = 11 },
    ['realestateagent'] = { label = "EJENDOMSMÆGLER", bossGrade = 11 },
    ['bahama'] = { label = "BAHAMA MAMAS", bossGrade = 11 },
    ['unicorn'] = { label = "UNICORN", bossGrade = 11 },
    ['burgershot'] = { label = "BURGERSHOT", bossGrade = 11 },
    ['uwu'] = { label = "UWU CAFE", bossGrade = 11 },
    ['beanmachine'] = { label = "BEAN MACHINE", bossGrade = 11 },
    ['koi'] = { label = "KOI", bossGrade = 11 },
    ['pizzathis'] = { label = "PIZZA THIS", bossGrade = 11 },
    ['bennys'] = { label = "BENNYS", bossGrade = 11 },
    ['lscustoms'] = { label = "LS CUSTOMS", bossGrade = 11 },
    ['previsor'] = { label = "PREVISOR", bossGrade = 5 },
    ['srevisor'] = { label = "SREVISOR", bossGrade = 5 },
    ['asair'] = { label = "ASAIR", bossGrade = 5 },
    ['hhansvar'] = { label = "HHANSVAR", bossGrade = 2 }
}

const BoostForward=3500.0;
const PI = 3.141592653;
const Max_Velocity_hor_1 = 100;
enum VelocityOverride {
    VelocityOvr_None = 0,
    VelocityOvr_Velocity,
    VelocityOvr_OnlyWhenNegative,
    VelocityOvr_InvertReuseVelocity
};
lastJumpTime <- 0.0;
jumpCount <- 0;
maxJumpCount <- 3;
tankJumpDir <- {};
const EARTHQUAKE_CHANCE = 0.3;
const DMG_GENERIC = 128;
const FL_ONGROUND = 1;
tankStuckTime <- {};
tankHighJumpTime <- {};
tankSpawnTime <- {};
function ClampHorizontalSpeed(vx, vy, maxSpeed)
{
    local speed = sqrt(vx*vx + vy*vy);

    if (speed > maxSpeed)
    {
        local scale = maxSpeed / speed;
        vx *= scale;
        vy *= scale;
    }

    return [vx, vy];
}
if (Director.GetGameModeBase()=="versus"&&!Entities.FindByName(null, "bind_tkhop")) {SpawnEntityFromTable("logic_timer",{targetname="bind_tkhop",vscripts="aitk_bhop",RefireTime = 0.5 , OnTimer = "!caller,runscriptcode,Thinks()"});}
function Thinks()
{
    local ent = null;
    while (ent = Entities.FindByClassname(ent, "player")) {
        if (ent.GetZombieType()==8 && !ent.IsDead() && !ent.IsDying()) {
            if (!Entities.FindByName(null, "tkbhop")) SpawnEntityFromTable("logic_timer", {targetname = "tkbhop", vscripts="aitk_bhop",RefireTime = 0.06, OnTimer = "!caller,runscriptcode,Tankruncmd()"});
            break;
        }
    }
}
function OnGameEvent_tank_spawn(params)
{
    local tank = GetPlayerFromUserID(params.userid);
    if (tank && tank.IsValid() && tank.GetZombieType() == 8) {
        local index = tank.GetEntityIndex();
        tankHighJumpTime[index] <- Time() - 10.0;
    }
}
function OnGameEvent_tank_killed(params)
{
    Msg("Come here baby");
    local tptk = 0;
    local ent = null;
    while (ent = Entities.FindByClassname(ent, "player")) {
        if (ent.GetZombieType()==8 && !ent.IsDead() && !ent.IsDying()) tptk++;
    }
    if (tptk == 0) EntFire("tkbhop","Kill",null,0,null);

    local tank = GetPlayerFromUserID(params.userid);
    if (tank) {
        local index = tank.GetEntityIndex();
        tankHighJumpTime.rawdelete(index);
        local tank_pos = tank.GetOrigin();
        printl("*** Tank died! Spawning 2 Hunters at " + tank_pos + " ***");
        ZSpawn({type = 3, pos = tank_pos});
        ZSpawn({type = 3, pos = tank_pos});
    }
}
function GetAliveSurvivor()
{
    local ent = null;
    while (ent = Entities.FindByClassname(ent, "player")) {
        if (ent.IsSurvivor() && !ent.IsDead() && !ent.IsDying()) return ent;
    }
    return null;
}
function GetVectorWithFloat(ent,propstring)
{
    if (!ent || !ent.IsValid()) return null;
    local tpos;
    if (propstring == "origin") tpos = ent.GetOrigin().tostring();
    else if (propstring == "vel") tpos = ent.GetVelocity().tostring();
    else if (propstring == "eyeangle") tpos = ent.EyeAngles().tostring();
    local tp_1 = split(split(tpos,"(")[1],")")[0];
    local tp_2 = split(tp_1,",");
    return [tp_2[0].tofloat(),tp_2[1].tofloat(),tp_2[2].tofloat()];
}
function GetDistance(dis1,dis2)
{
    if (dis1 && dis2) return sqrt(pow(dis1[0]-dis2[0],2)+pow(dis1[1]-dis2[1],2)+pow(dis1[2]-dis2[2],2));
    return null;
}
function GetClosetSurvivor(rp)
{
    local closetSur = GetAliveSurvivor();
    if (!closetSur) return null;
    local minDist = 999999.0;
    local ent = null;
    while (ent = Entities.FindByClassname(ent,"player")) {
        if (ent.IsValid() && ent.IsSurvivor() && !ent.IsDead() && !ent.IsDying()) {
            local surPos = GetVectorWithFloat(ent,"origin");
            local dist = GetDistance(rp, surPos);
            if (dist < minDist) {
                minDist = dist;
                closetSur = ent;
            }
        }
    }
    return closetSur;
}
function DisableButton(ent,button)
{
    local buttons = NetProps.GetPropInt(ent,"m_afButtonDisabled" );
    NetProps.SetPropInt(ent,"m_afButtonDisabled", ( buttons | button ) );
}
function EnableButton(ent,button)
{
    local buttons = NetProps.GetPropInt(ent,"m_afButtonDisabled" );
    NetProps.SetPropInt(ent,"m_afButtonDisabled", ( buttons & ~button ) );
}
function ForceButton(ent,button)
{
    local buttons = NetProps.GetPropInt(ent,"m_afButtonForced");	
    NetProps.SetPropInt(ent,"m_afButtonForced",(buttons | button));
}
function UnForceButton(ent,button)
{
    local buttons = NetProps.GetPropInt(ent,"m_afButtonForced");	
    NetProps.SetPropInt(ent,"m_afButtonForced",( buttons & ~button ));
}
function CalcYawToTarget(ent, target) {
    local tankPos = GetVectorWithFloat(ent, "origin");
    local targetPos = GetVectorWithFloat(target, "origin");
    local dx = targetPos[0] - tankPos[0];
    local dy = targetPos[1] - tankPos[1];
    return atan2(dy, dx) * 180.0 / PI;
}
function LookAtTarget(ent, target) {
    if (!target) return;
    local yaw = CalcYawToTarget(ent, target);
    local eyeAngles = QAngle(0, yaw, 0);
    ent.SetAngles(eyeAngles);
    ent.SnapEyeAngles(eyeAngles);
}
function DoEarthquake(ent) {
    local tank_pos = ent.GetOrigin();
    ScreenShake(tank_pos, 10.0, 10.0, 0.5, 500.0);
    local player = null;
    while (player = Entities.FindByClassnameWithin(player, "player", tank_pos, 500.0)) {
        if (player.IsValid() && player.IsSurvivor() && player.GetHealth() > 0) {
            player.TakeDamage(5.0, DMG_GENERIC, ent);
            player.Stagger(tank_pos);
            printl("Earthquake stunned survivor!");
        }
    }
    printl("Tank caused small earthquake!");
}
function Tankruncmd()
{
    local tank_ent = null;
    while (tank_ent = Entities.FindByClassname(tank_ent,"player")) {
        if (tank_ent.GetZombieType() != 8 || tank_ent.IsDead() || tank_ent.IsDying()) continue;

        local flags = NetProps.GetPropInt(tank_ent,"m_fFlags");
        local fVelocity = GetVectorWithFloat(tank_ent,"vel");
        local currentspeed = sqrt(pow(fVelocity[0],2.0)+pow(fVelocity[1],2.0));
        local tankpos = GetVectorWithFloat(tank_ent,"origin");
        local closetsur = GetClosetSurvivor(tankpos);
        local hassight = NetProps.GetPropInt(tank_ent,"m_hasVisibleThreats");

        if (NetProps.GetPropInt(tank_ent,"m_fFlags") & 1 && NetProps.GetPropInt(tank_ent,"m_nButtons") & 2) {
            local up_speed = (NetProps.GetPropInt(tank_ent,"m_fFlags") & 2) ? 297 : 247;
            local Angles = tank_ent.EyeAngles();
            local Velocity_x = Max_Velocity_hor_1*cos(Angles.y*PI/180);
            local Velocity_y = Max_Velocity_hor_1*sin(Angles.y*PI/180);
            NetProps.SetPropVector(tank_ent,Vector(Velocity_x,Velocity_y,up_speed));
        }

        local tp_dist = null;
        if (closetsur) tp_dist = GetDistance(GetVectorWithFloat(closetsur,"origin"),tankpos);

        if (hassight && tp_dist > 250 && tp_dist < 700 && currentspeed > 201.0) {
            if (flags & 1) {
                ForceButton(tank_ent,4);
                ForceButton(tank_ent,2);
                ForceButton(tank_ent,8);

                if (tank_ent.GetVelocity().z > 500) {
                    UnForceButton(tank_ent, 2);
                    UnForceButton(tank_ent, 4);
                    UnForceButton(tank_ent, 8);
                }

                local buttonMask = tank_ent.GetButtonMask();
                if (buttonMask == 8 || buttonMask & 16 || buttonMask & 512 || buttonMask & 1024) ClientPush(tank_ent);
            }
            if (NetProps.GetPropInt(tank_ent,"movetype") == 9) {
                UnForceButton(tank_ent,2);
                UnForceButton(tank_ent,4);
                UnForceButton(tank_ent,8);
            }
        } else if ((tp_dist > 650 || tp_dist < 180) && currentspeed < 190.0) {
            UnForceButton(tank_ent,2);
            UnForceButton(tank_ent,4);
            UnForceButton(tank_ent,8);
        }

        local entIndex = tank_ent.GetEntityIndex();
        local currentTime = Time();
        if (!(entIndex in tankSpawnTime))
        {
            tankSpawnTime[entIndex] <- Time();
        }
        if (currentspeed < 50.0 && !tankJumpDir.rawin(entIndex)) {
            if (!tankStuckTime.rawin(entIndex)) tankStuckTime[entIndex] <- currentTime;
            else if (currentTime - tankStuckTime[entIndex] > 2.0) {
                printl("*** Tank stuck! Unforcing buttons and giving nudge. ***");
                UnForceButton(tank_ent, 2);
                UnForceButton(tank_ent, 4);
                UnForceButton(tank_ent, 8);
                NetProps.SetPropInt(tank_ent, "m_afButtonForced", 0);
                NetProps.SetPropFloat(tank_ent, "m_flLaggedMovementValue", 1.0);
                tank_ent.SetVelocity(Vector(100.0, 100.0, 200.0));
                tankStuckTime.rawdelete(entIndex);
            }
        } else tankStuckTime.rawdelete(entIndex);

        if (!tankHighJumpTime.rawin(entIndex)) tankHighJumpTime[entIndex] <- currentTime - 10.0;
        local lastHighJump = tankHighJumpTime[entIndex];
        local isOnGround = (flags & FL_ONGROUND) != 0;

        // === HIGH JUMP mỗi 10 giây ===
        if (currentTime - lastHighJump >= 10.0 && isOnGround) {
            if (Time() - tankSpawnTime[entIndex] < 2.0)
            continue;
            printl("*** Tank high jump every 10s! Time since last: " + (currentTime - lastHighJump) + " ***");
            local highVz = 870.0;
            // FIX: Dùng SetVelocity để đẩy lên ngay lập tức trong cùng frame
            local vel = tank_ent.GetVelocity();
            tank_ent.SetVelocity(Vector(vel.x, vel.y, 550.0));
            tankJumpDir[entIndex] <- [0.0, 0.0, highVz, 10];
            tankHighJumpTime[entIndex] = currentTime;
        }

        // === XỬ LÝ JUMP DIR ===
        if (tankJumpDir.rawin(entIndex)) {
            local curVel = GetVectorWithFloat(tank_ent, "vel");
            local dir = tankJumpDir[entIndex];
            local vx = dir[0];
            local vy = dir[1];
            local vz = dir[2];
            local remain = dir[3];
            
            // BOOST HƯỚNG 3 TICK ĐẦU (lao cực gắt nhưng tự nhiên)
        if (remain >= 9 && closetsur) {
            local tankPos = GetVectorWithFloat(tank_ent, "origin");
            local targetPos = GetVectorWithFloat(closetsur, "origin");

            local dx = targetPos[0] - tankPos[0];
            local dy = targetPos[1] - tankPos[1];

            local len = sqrt(dx*dx + dy*dy);
            if (len > 0.0){
                dx /= len;
                dy /= len;

                local boostForce = 220.0;   // chỉnh 150–220 tùy độ gắt
                tank_ent.SetVelocity(Vector(
                curVel[0] + dx * boostForce,
                curVel[1] + dy * boostForce,
                curVel[2]
        ));
        curVel = GetVectorWithFloat(tank_ent, "vel"); // CẬP NHẬT LẠI
    }
}

            local zVel = curVel[2];
            local isFallingSlow = zVel < 0 && abs(zVel) < 100.0;

            local horizontalSpeed = sqrt(curVel[0]*curVel[0] + curVel[1]*curVel[1]);

            // FIX: Chỉ hủy jump sớm nếu đã rời đất (remain < 8) mà speed quá thấp
            if (horizontalSpeed < 100.0 && remain < 8) {
                tankJumpDir.rawdelete(entIndex);
                continue;
            }

            if (!isOnGround && !isFallingSlow) {
                // Tank đang bay: apply velocity bình thường
                tankJumpDir[entIndex][3] = remain - 1;
                if ((vx != 0.0 || vy != 0.0) && closetsur) LookAtTarget(tank_ent, closetsur);
            } else if (remain >= 8) {
                // FIX: Grace period — tank chưa kịp rời đất, vẫn tiếp tục apply velocity
                tankJumpDir[entIndex][3] = remain - 1;
            }

            // FIX: Chỉ kết thúc jump khi hết remain HOẶC đã bay rồi mới hạ xuống đất
            if (remain <= 1 || (isOnGround && remain < 8)) {
                tankJumpDir.rawdelete(entIndex);
                if (vx == 0.0 && vy == 0.0) DoEarthquake(tank_ent);
                else if (RandomFloat(0.0, 1.0) < EARTHQUAKE_CHANCE) DoEarthquake(tank_ent);
            }
        }
    }
}
function ClientPush(ent)
{
    local closetsur = GetClosetSurvivor(GetVectorWithFloat(ent, "origin"));
    if (!closetsur) return;

    local currentTime = Time();
    local flags = NetProps.GetPropInt(ent, "m_fFlags");
    local isOnGround = (flags & 1) != 0;

    local tp_dist = GetDistance(GetVectorWithFloat(closetsur, "origin"), GetVectorWithFloat(ent, "origin"));
    if (tp_dist <= 200.0) {
        lastJumpTime = currentTime;
        jumpCount = maxJumpCount;
        return;
    }

    if (currentTime - lastJumpTime >= 10.0) jumpCount = 0;

    if ((currentTime - lastJumpTime >= 0.5) && jumpCount < maxJumpCount && isOnGround) {
        LookAtTarget(ent, closetsur);

        local vel = GetVectorWithFloat(ent, "vel");
        local speed = sqrt(vel[0]*vel[0] + vel[1]*vel[1]);

        local push_forward, vz, vx, vy;
        local dir = [GetVectorWithFloat(closetsur, "origin")[0] - GetVectorWithFloat(ent, "origin")[0], GetVectorWithFloat(closetsur, "origin")[1] - GetVectorWithFloat(ent, "origin")[1]];
        local norm = sqrt(dir[0]*dir[0] + dir[1]*dir[1]);
        dir[0] /= norm; dir[1] /= norm;

        if (speed < 120.0) {
            push_forward = 770.0; 
            vz = 420.0; 
            NetProps.SetPropFloat(ent, "m_flLaggedMovementValue", 1.8);
        } else if (speed > 300.0) {
            push_forward = 770.0; 
            vz = 380.0; 
            NetProps.SetPropFloat(ent, "m_flLaggedMovementValue", 1.12);
        } else {
            push_forward = 490.0; 
            vz = 370.0; 
            NetProps.SetPropFloat(ent, "m_flLaggedMovementValue", 1.2);
        }
        vx = push_forward * dir[0];
        vy = push_forward * dir[1];

        
        local clamped = ClampHorizontalSpeed(vx, vy, 700.0);
        vx = clamped[0];
        vy = clamped[1];

        // FIX: Dùng SetVelocity để đẩy lên ngay lập tức trong cùng frame
        ent.SetVelocity(Vector(vx, vy, vz));
        tankJumpDir[ent.GetEntityIndex()] <- [vx, vy, vz, 10];

        lastJumpTime = currentTime;
        jumpCount += 1;

        UnForceButton(ent, 2); UnForceButton(ent, 4); UnForceButton(ent, 8);
    }
}

__CollectEventCallbacks(scope(), "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

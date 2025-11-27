const BoostForward=2500.0; // Bhop
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
maxJumpCount <- 3; // chỉnh số lần Tank được nhảy tại đây
tankJumpDir <- {};  // key = Tank entity index, value = [vx, vy, vz, remain]
const EARTHQUAKE_CHANCE = 0.3;
const DMG_GENERIC = 128;
const FL_ONGROUND = 1;

if (Director.GetGameModeBase()=="coop"&&!Entities.FindByName(null, "bind_tkhop")) {SpawnEntityFromTable("logic_timer",{targetname="bind_tkhop",vscripts="aitk_bhop",RefireTime = 0.5 , OnTimer = "!caller,runscriptcode,Thinks()"});}
function Thinks()
{
    local i,ent;
    for(i=0;i<16;i++)
    {
        ent=Entities.FindByClassname(ent,"player");
        if(ent !=null &&ent.GetZombieType()==8&&!ent.IsDead()&&!ent.IsDying())
        {
            if (!Entities.FindByName(null, "tkbhop")) {
            SpawnEntityFromTable("logic_timer", {targetname = "tkbhop", vscripts="aitk_bhop",RefireTime = 0.06, OnTimer = "!caller,runscriptcode,Tankruncmd()"});
            }
        }
    }
}
function OnGameEvent_tank_killed(params)
{
    Msg("Come here baby");
    local i;
    local tptk = 0;
    local ent;
    for(i=0;i<16;i++)
    {
        ent=Entities.FindByClassname(ent,"player");
        if(ent !=null &&ent.GetZombieType()==8&&!ent.IsDead()&&!ent.IsDying())
        {
            tptk+=1;
        }else if(ent == null)
        {
            break;
        }
    }
    if(tptk == 0)
    {
        EntFire("tkbhop","Kill",null,0,null);
    }
}
function GetAliveSurvivor()
{
    local tp_sr;
    local newi;
    local ent;
    for(newi = 0;newi < 18;newi++)
    {
        ent =Entities.FindByClassname(ent,"player");
        if(ent != null && ent.IsSurvivor() && !ent.IsDead() && !ent.IsDying())
        {
            tp_sr=ent;
            break;
            //Msg(tp_sr[newi]);
        }else if(ent==null)
        {
            break;
        }
    }
        return tp_sr;
    
}
function GetVectorWithFloat(ent,propstring)
{
    local tpos;
    if(ent == null || ent.IsValid() == false)
    {
        return null;
    }else if(propstring == "origin")
    {
        tpos = ent.GetOrigin().tostring();
    }else if(propstring == "vel")
    {
        tpos = ent.GetVelocity().tostring();
    }
    else if(propstring == "eyeangle")
    {
        tpos = ent.EyeAngles().tostring();
    }
    local tp_1 = split(split(tpos,"(")[1],")")[0];
    local tp_2 = split(tp_1,",");
    local tp_3 = [tp_2[0].tofloat(),tp_2[1].tofloat(),tp_2[2].tofloat()];
    return tp_3;

}
function GetDistance(dis1,dis2)//phương pháp làGetDistance([0，0，0],[0，0，0]);
{
    if(dis1 != null && dis2 != null)
    {   
        local tp_dis = pow(dis1[0]-dis2[0],2)+pow(dis1[1]-dis2[1],2)+pow(dis1[2]-dis2[2],2);
        return sqrt(tp_dis);
    }
    else return;
    
}
function GetClosetSurvivor(rp)//phương pháp đồng trên dùng[0，0，0]
{
    local surPos=[0,0,0];
    local closetSur = GetAliveSurvivor();
    surPos = GetVectorWithFloat(closetSur,"origin");
    local iclosetdis = GetDistance(rp,surPos);
    local i;
    local ent;
    for(i=0;i<18;i++)
    {
        ent = Entities.FindByClassname(ent,"player");
        if(ent != null && ent.IsSurvivor() && !ent.IsDead() && !ent.IsDying())
        {
            surPos = GetVectorWithFloat(ent,"origin");
            local tp_posdis = GetDistance(rp,surPos);
            if(iclosetdis < 0)
            {
                iclosetdis = tp_posdis;
                closetSur = ent;
            }else if (tp_posdis < iclosetdis)
            {
                iclosetdis = tp_posdis;
                closetSur = ent;
            }
        }else if(ent == null)
        {
            break;
        }
    }
    return closetSur;
}
function DisableButton(ent,button)//có thể làm không nhấn nút này.
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
    local yaw = CalcYawToTarget(ent, target);
    local eyeAngles = QAngle(0, yaw, 0);
    ent.SetAngles(eyeAngles);
    ent.SnapEyeAngles(eyeAngles);
}
function DoEarthquake(ent) {
    local tank_pos = ent.GetOrigin();
    ScreenShake(tank_pos, 10.0, 10.0, 0.5, 400.0);
    local player = null;
    while (player = Entities.FindByClassnameWithin(player, "player", tank_pos, 400.0))
    {
        if (player.IsValid() && player.IsSurvivor() && player.GetHealth() > 0)
        {
            player.TakeDamage(5.0, DMG_GENERIC, ent);
            player.Stagger(tank_pos);
            printl("Earthquake stunned survivor!");
        }
    }
    printl("Tank caused small earthquake!");
}
function Tankruncmd()
{
    //local tp_tank;
    local flags;
    local fVelocity;
    local currentspeed;
    local clienteyes;
    local tankpos;
    local closetsur;
    local hassight;
    local tank_ent;
    local i;
    for(i=0;i<16;i++)
    {
        tank_ent = Entities.FindByClassname(tank_ent,"player");
        if(tank_ent != null && tank_ent.GetZombieType() == 8 && !tank_ent.IsDead() && !tank_ent.IsDying())
        {
            //Msg(tp_tank[1]+"\n");
            //DisableButton(tank_ent,2048);
            flags=NetProps.GetPropInt(tank_ent,"m_fFlags");
            fVelocity=GetVectorWithFloat(tank_ent,"vel");
            currentspeed=sqrt(pow(fVelocity[0],2.0)+pow(fVelocity[1],2.0));
            //clienteyes=GetVectorWithFloat(tank_ent,"eyeangle");
            tankpos=GetVectorWithFloat(tank_ent,"origin");
            closetsur=GetClosetSurvivor(tankpos);
            hassight=NetProps.GetPropInt(tank_ent,"m_hasVisibleThreats");
            if (NetProps.GetPropInt(tank_ent,"m_fFlags") & (1 << 0) && NetProps.GetPropInt(tank_ent,"m_nButtons") & (1 << 1)) {
                local up_speed = (NetProps.GetPropInt(tank_ent,"m_fFlags") & (1 << 1) /* Player is fully crouched */ ) ? 297 : 247;
                local Angles = tank_ent.EyeAngles();
                local Velocity_x = Max_Velocity_hor_1*cos(Angles.y*PI/180);
                local Velocity_y = Max_Velocity_hor_1*sin(Angles.y*PI/180);
                NetProps.SetPropVector(tank_ent,"m_vecBaseVelocity",Vector(Velocity_x,Velocity_y,up_speed));
                //Say(null, "your speed = " + getHirozontalSpeed(ent), false);
            }
            local tp_dist = GetDistance((GetVectorWithFloat(closetsur,"origin")),tankpos);
            //Msg(flags+"\n");
            if (hassight && tp_dist > 250 && tp_dist < 700 && currentspeed > 201.0)
            {
                 
                if(flags & 1)
                {
                    ForceButton(tank_ent,4);
                    ForceButton(tank_ent,2);
                    ForceButton(tank_ent,8);

                    if(tank_ent.GetVelocity().z > 500){
                        UnForceButton(tank_ent, 2);
                        UnForceButton(tank_ent, 4);
                        UnForceButton(tank_ent, 8);
                    }
                    
                    if(tank_ent.GetButtonMask() == 8)
                    {
                        //Msg(currentspeed+"前进\n");
                        ClientPush(tank_ent);
                    }
                    if(tank_ent.GetButtonMask()&16)
                    {
                        //Msg(currentspeed+"后退\n");
                        //clienteyes[1]+=180.0;
                        ClientPush(tank_ent);
                    }
                    if(tank_ent.GetButtonMask()&512)
                    {
                        //Msg(currentspeed+"左边\n");
                        //clienteyes[1]+=90.0;
                        ClientPush(tank_ent);
                    }
                    if(tank_ent.GetButtonMask()&1024)
                    {
                        //Msg(currentspeed+"右边\n");
                        //clienteyes[1]+=-90.0;
                        ClientPush(tank_ent);
                    }
                }
                if(NetProps.GetPropInt(tank_ent,"movetype") == 9)
                {
                    UnForceButton(tank_ent,2);
                    UnForceButton(tank_ent,4);
                    UnForceButton(tank_ent,8);
                }
            }else if((tp_dist>650 || tp_dist<180)&&currentspeed<190.0)
            {
                //Msg(1+"\n")
                UnForceButton(tank_ent,2);
                UnForceButton(tank_ent,4);
                UnForceButton(tank_ent,8);
            }
        }else if(tank_ent != null && tank_ent.GetZombieType() != 8)
        {
            continue;
        }else if (tank_ent == null)
        {
            break;
        }

        // Duy trì lực đẩy nếu đang trong giai đoạn bay
        local entIndex = tank_ent.GetEntityIndex();
        if (!tank_ent || !tank_ent.IsValid()) return;

        local flags = NetProps.GetPropInt(tank_ent, "m_fFlags");
        local isOnGround = (flags & (1 << 0)) != 0;
        if (tankJumpDir.rawin(entIndex)) {
            local curVel = GetVectorWithFloat(tank_ent, "vel");
            local dir = tankJumpDir[entIndex];
            local vx = dir[0];
            local vy = dir[1];
            local vz = dir[2];
            local remain = dir[3];

            local zVel = curVel[2];
            local isFallingSlow = zVel < 0 && abs(zVel) < 100.0;

            //Ktra tank đứng yên
            local horizontalSpeed = sqrt(curVel[0]*curVel[0] +curVel[1]*curVel[1]);
            if(horizontalSpeed < 100.0) {
                //Tank đứng yên, hủy bunny
                tankJumpDir.rawdelete(entIndex);
                NetProps.SetPropVector(tank_ent, "m_vecBaseVelocity", Vector(0,0,0));
                return;
            }

            // Chỉ boost nếu đang trên không
            if (!isOnGround && !isFallingSlow) {
                NetProps.SetPropVector(tank_ent, "m_vecBaseVelocity", Vector(vx, vy, vz));
                tankJumpDir[entIndex][3] = remain - 1;
            }

            // Xóa nếu đã hết frame hoặc chạm đất
            if (remain <= 1 || isOnGround) {
                tankJumpDir.rawdelete(entIndex);
                if (RandomFloat(0.0, 1.0) < EARTHQUAKE_CHANCE) {
                    DoEarthquake(tank_ent);
                }
            }
        } else {
            NetProps.SetPropVector(tank_ent, "m_vecBaseVelocity", Vector(vx, vy, vz));
            tankJumpDir[entIndex][3] = remain - 1;  
        }

    }
}

function ClientPush(ent)
{
    local closetsur = GetClosetSurvivor(GetVectorWithFloat(ent, "origin"));
    if (closetsur == null) return;

    local currentTime = Time();
    local flags = NetProps.GetPropInt(ent, "m_fFlags");
    local isOnGround = (flags & (1 << 0)) != 0;

    local tp_dist = GetDistance(GetVectorWithFloat(closetsur, "origin"), GetVectorWithFloat(ent, "origin"));
    if (tp_dist <= 200.0) {
        // Đã gần, dừng sequence và cooldown 10 giây
        lastJumpTime = currentTime;
        jumpCount = maxJumpCount;  // Fake hết jump để reset
        return;
    }

    if (currentTime - lastJumpTime >= 10.0) {
        jumpCount = 0;  // Reset sequence sau cooldown
    }

    if ((currentTime - lastJumpTime >= 0.5) && jumpCount < maxJumpCount && isOnGround) {
        LookAtTarget(ent, closetsur);  // Lock hướng nhìn và model về survivor

        local vel = GetVectorWithFloat(ent, "vel");
        local speed = sqrt(vel[0]*vel[0] + vel[1]*vel[1]);

        local push_forward;
        local vz;
        local vx, vy;

        local dir = [GetVectorWithFloat(closetsur, "origin")[0] - GetVectorWithFloat(ent, "origin")[0],
                     GetVectorWithFloat(closetsur, "origin")[1] - GetVectorWithFloat(ent, "origin")[1]];
        local norm = sqrt(dir[0]*dir[0] + dir[1]*dir[1]);
        dir[0] /= norm; dir[1] /= norm;  // Normalize hướng về survivor

        if (speed < 120.0) {
            push_forward = 650.0;
            vz = 450.0;
            vx = push_forward * dir[0];
            vy = push_forward * dir[1];
            NetProps.SetPropFloat(ent, "m_flLaggedMovementValue", 1.8);
        }
        else if (speed > 300.0) {
            push_forward = 300.0;
            vz = 380.0;
            vx = push_forward * dir[0];
            vy = push_forward * dir[1];
            NetProps.SetPropFloat(ent, "m_flLaggedMovementValue", 1.12);
        }
        else {
            push_forward = 430.0;
            vz = 350.0;
            vx = push_forward * dir[0];
            vy = push_forward * dir[1];
            NetProps.SetPropFloat(ent, "m_flLaggedMovementValue", 1.2);
        }

        // Áp lực đẩy và lưu hướng
        NetProps.SetPropVector(ent, "m_vecBaseVelocity", Vector(vx, vy, vz));
        tankJumpDir[ent.GetEntityIndex()] <- [vx, vy, vz, 2];

        lastJumpTime = currentTime;
        jumpCount += 1;

        UnForceButton(ent, 2);  // Jump
        UnForceButton(ent, 4);  // Duck
        UnForceButton(ent, 8);  // Forward
    }
}

// Kết nối event (thêm tank_spawn để debug nếu cần)
__CollectEventCallbacks(scope(), "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
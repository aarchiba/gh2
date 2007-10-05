unit gh2arena;
	{ Oct 23, 2006: }
	{ This is it. I've been programming GH2 for a while now, and even though }
	{ it's getting more and more playable all the time it'll still be a long }
	{ time before it's really playable. So I started to think back to the humble }
	{ beginnings of GH1. I decided that development of GH2 could be improved if }
	{ I added arena mode; a simple, combat-focused use of the engine that would }
	{ provide a fun game while the RPG campaign gets bulked up. I also got a few }
	{ comments on the forum indicating that I should put more work into tactics }
	{ mode. So here it is, the new humble beginning of GearHead arena, Mk2. }
{
	GearHead2, a roguelike mecha CRPG
	Copyright (C) 2005 Joseph Hewitt

	This library is free software; you can redistribute it and/or modify it
	under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation; either version 2.1 of the License, or (at
	your option) any later version.

	The full text of the LGPL can be found in license.txt.

	This library is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
	General Public License for more details. 

	You should have received a copy of the GNU Lesser General Public License
	along with this library; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
}
{$LONGSTRINGS ON}

interface

{$IFDEF ASCII}
uses gears,locale,vidgfx;
{$ELSE}
uses gears,locale,glgfx;
{$ENDIF}

const
	NAG_ArenaMissionInfo = 20;
		NAS_PayRate = 1;	{ Determines how much money the unit will earn upon }
					{ completing the mission. }
		NAS_Pay = 2;		{ Holds the actual calculated pay value. }

Procedure StartArenaCampaign;
Procedure RestoreArenaCampaign( RDP: RedrawProcedureType );

implementation

{$IFDEF ASCII}
uses arenaplay,arenascript,interact,gearutil,narration,texutil,ghprop,rpgdice,ability,
     ghchars,ghweapon,movement,ui4gh,vidmap,vidmenus,gearparser,playwright,randmaps,wmonster,
	vidinfo,pcaction,menugear,navigate,services,skilluse,training,backpack,chargen;
{$ELSE}
uses arenaplay,arenascript,interact,gearutil,narration,texutil,ghprop,rpgdice,ability,
     ghchars,ghweapon,movement,ui4gh,glmap,glmenus,gearparser,playwright,randmaps,wmonster,
	glinfo,pcaction,menugear,navigate,services,skilluse,training,backpack,chargen;
{$ENDIF}

Const
	GS_CharacterSet = 1;

	NumArenaNPCs = 6;
	ANPC_FactionHead = 1;
	ANPC_Commander = 2;
	ANPC_Mechanic = 3;
	ANPC_Medic = 4;
	ANPC_Supply = 5;
	ANPC_Intel = 6;

var
	ADR_Source: GearPtr;	{ Source gear for various redrawers. }
	ADR_SourceMenu: RPGMenuPtr;
	ADR_HQCamp: CampaignPtr;

	ADR_NumPilotsSelected,ADR_PilotsAllowed: Integer;

	ADR_PilotMenu,ADR_MechaMenu: RPGMenuPtr;

	ANPC_MasterPersona: GearPtr;


{ *** REDRAW PROCEDURES *** }

Procedure BasicArenaRedraw;
	{ Just draw the basic setup for the arena mode menus. }
begin
	SetupArenaDisplay;
	if ADR_PilotMenu <> Nil then DisplayMenu( ADR_PilotMenu , Nil );
	if ADR_MechaMenu <> Nil then DisplayMenu( ADR_MechaMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
end;

Procedure HQMonologue( Adv: GearPtr; ArenaNPC: LongInt; Msg: String );
	{ NPC is about to deliver a line. }
var
	NPC: GearPtr;
	A: Char;
begin
	NPC := SeekGearByCID( Adv^.InvCom , ArenaNPC );
	repeat
		BasicArenaRedraw;
		DoMonologueDisplay( Nil , NPC , Msg );
		DoFlip;

		A := RPGKey;
	until IsMoreKey( A );

	DialogMsg( '[' + GearName( NPC ) + ']: ' + Msg );
end;

Procedure SelectAMissionRedraw;
	{ Do the basic display, then draw the select forces dialog on top of that. }
begin
	BasicArenaRedraw;
	SetupMemoDisplay;
end;

Procedure SelectAMForcesRedraw;
	{ Do the basic display, then draw the select forces dialog on top of that. }
begin
	BasicArenaRedraw;
	SetupMemoDisplay;
	CMessage( BStr( ADR_NumPilotsSelected ) + '/' + Bstr( ADR_PilotsAllowed ) + ' ' + MsgString( 'ARENA_SAMFRD_PilotsSelected' ) , ZONE_MemoMenu , InfoGreen );
end;

Procedure ViewMechaRedraw;
	{ The PC is viewing the mecha list. }
var
	N: Integer;
	Part: GearPtr;
begin
	SetupArenaDisplay;
	if ADR_PilotMenu <> Nil then DisplayMenu( ADR_PilotMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Part , ZONE_ArenaInfo );
			end;
		end;
	end;
end;

Procedure ViewPilotRedraw;
	{ The PC is viewing the mecha list. }
var
	N: Integer;
	Part: GearPtr;
begin
	SetupArenaDisplay;
	if ADR_MechaMenu <> Nil then DisplayMenu( ADR_MechaMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Part , ZONE_ArenaInfo );
			end;
		end;
	end;
end;

Procedure ViewSourcePilotRedraw;
	{ The PC is viewing a specific gear. }
begin
	SetupArenaDisplay;
	if ADR_MechaMenu <> Nil then DisplayMenu( ADR_MechaMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( ADR_Source , ZONE_ArenaInfo );
	end;
end;

Procedure ViewSourceMechaRedraw;
	{ The PC is viewing a specific gear. }
begin
	SetupArenaDisplay;
	if ADR_PilotMenu <> Nil then DisplayMenu( ADR_PilotMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( ADR_Source , ZONE_ArenaInfo );
	end;
end;

Procedure AddPilotRedraw;
	{ Draw the basic setup for the arena mode menus, then display character info }
	{ for ADR_SOURCE. }
begin
	BasicArenaRedraw;
	if ADR_Source <> Nil then CharacterDisplay( ADR_Source , Nil );
end;

Procedure PurchaseHardwareRedraw;
	{ The PC is buying hardware. Open the shopping display! }
var
	N: Integer;
	Part: GearPtr;
begin
	BasicArenaRedraw;
	SetupFHQDisplay;
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Part , ZONE_ItemsInfo );
			end;
		end;
	end;
end;

Procedure ViewListRedraw;
	{ The PC is viewing either the pilots list or the mecha list. }
var
	N: Integer;
	Part: GearPtr;
begin
	BasicArenaRedraw;
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Part , ZONE_ArenaInfo );
			end;
		end;
	end;
end;

Procedure ViewSourceRedraw;
	{ The PC is viewing a specific gear. }
begin
	BasicArenaRedraw;
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( ADR_Source , ZONE_ArenaInfo );
	end;
end;

Procedure DoPurchaseRedraw;
	{ The PC has browsed, and is now making a real purchase. }
begin
	BasicArenaRedraw;
	SetupFHQDisplay;
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( ADR_Source , ZONE_ItemsInfo );
	end;
end;


{ *** UTILITY FUNCTIONS *** }

Function ArenaNPCMessage( Adv: GearPtr; ArenaNPC: LongInt; const Msg_Key: String ): String;
	{ Try to find an appropriate message for the requested NPC to say. }
var
	NPC: GearPtr;
begin
	NPC := SeekGearByCID( Adv^.InvCom , ArenaNPC );
	ArenaNPCMessage := NPCScriptMessage( Msg_Key , Nil , NPC , ANPC_MasterPersona );
end;

Function FindMechasPilot( U , Mek: GearPtr ): GearPtr;
	{ Search unit U to locate whatever pilot is assigned to mecha Mek. }
	{ If no such pilot is found, clear Mek's PILOT attribute and }
	{ return Nil. }
var
	pc,mpc: GearPtr;
	name: String;
begin
	{ Begin by finding the pilot's name. }
	name := SAttValue( Mek^.SA , 'pilot' );

	{ Search through the unit's Sub looking for a character of }
	{ this name. }
	pc := U^.SubCom;
	mpc := Nil;
	while ( pc <> Nil ) and ( mpc = Nil ) do begin
		if pc^.G = GG_Character then begin
			if GearName( PC ) = name then mpc := pc;
		end;
		pc := pc^.Next;
	end;

	{ If the required pilot could not be found, }
	{ delete this mecha's PILOT attribute. }
	if mpc = Nil then begin
		SetSAtt( Mek^.SA , 'pilot <>' );
	end;

	FindMechasPilot := mpc;
end;

Function UnitSkill( HQCamp: CampaignPtr; Skill: Integer ): Integer;
	{ Return the "unit skill" value for the requested skill. Usually this }
	{ will be the highest skill rank in the unit. }
begin
	{ Check through every mek on the board. }
	UnitSkill := SkillValue( HQCamp^.Source , Skill );
end;

Function ModifiedCost( HQCamp: CampaignPtr; BaseCost: LongInt; Skill: Integer ): LongInt;
	{ The unit has to spend money on something, but this amount of money can be }
	{ reduced based on a certain skill. When buying things the skill is shopping. }
	{ When fixing things the skill is the appropriate repair skill. }
begin
	{ Determine the unit skill value. }
	if ( Skill >= 1 ) and ( Skill <= NumSkill ) then begin
		Skill := UnitSkill( HQCamp , Skill );
	end else Skill := 0;

	{ Each point of skill gives a 2% discount on the cost. }
	Skill := Skill * 2;
	{ You can't get more than a 75% discount, no matter how you try. }
	if Skill > 75 then Skill := 75;

	{ Return the modified cost. }
	ModifiedCost := BaseCost * ( 100 - Skill ) div 100;
end;

Function AHQRepairCost( HQCamp: CampaignPtr; Part: GearPtr ): LongInt;
	{ Return the cash cost to repair this gear completely. }
var
	Skill: Integer;
	Total: LongInt;
begin
	Total := 0;
	for Skill := 1 to NumSkill do begin
		if SkillMan[ Skill].Usage = USAGE_Repair then Total := Total + ModifiedCost( HQCamp , RepairMasterCost( Part , Skill ) , Skill );
	end;
	AHQRepairCost := Total;
end;

Procedure DoFullRepair( HQCamp: CampaignPtr; Part: GearPtr );
	{ Do all the repair that this gear needs. }
var
	Skill: Integer;
	Cost,TRD: LongInt;
begin
	for Skill := 1 to NumSkill do begin
		if SkillMan[ Skill].Usage = USAGE_Repair then begin
			Cost := RepairMasterCost( Part , Skill );
			if Cost > 0 then begin
				TRD := TotalRepairableDamage( Part , SKill );
				ApplyRepairPoints( Part , Skill , TRD );
				AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , -Cost );
			end;
		end;
	end;
end;

Function HQCash( HQCamp: CampaignPtr ): LongInt;
	{ This is pretty much just a macro for returning the amount of }
	{ cash this arena unit has. }
begin
	HQCash := NAttValue( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits );
end;

Function HQRenown( HQCamp: CampaignPtr ): LongInt;
	{ This is pretty much just a macro for returning the amount of }
	{ renown this arena unit has. }
begin
	HQRenown := NAttValue( HQCamp^.Source^.NA , NAG_CharDescription , NAS_Renowned );
end;

Function HQFac( HQCamp: CampaignPtr ): Integer;
	{ Return the faction of this arena unit. }
begin
	HQFac := NAttValue( HQCamp^.Source^.NA , NAG_Personal , NAS_FactionID );
end;

Function HQMaxMissions( HQCamp: CampaignPtr ): Integer;
	{ Return the maximum number of missions this unit can have available. }
	{ This number is based on the unit's conversation skill. }
var
	C: Integer;
begin
	C := UnitSkill( HQCamp , NAS_Conversation ) div 3;
	if C < 3 then C := 3;
	HQMaxMissions := C;
end;


Procedure ArenaReloadMaster( HQCamp: CampaignPtr; PC: GearPtr );
	{ Reload the mecha, and make the unit PAY!!! Money, that is. }
	{ Bullets aren't free. }
begin
	AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , -ReloadMasterCost( PC ) );
	DoReloadMaster( PC );
end;

Procedure PrepMission( HQCamp: CampaignPtr; Scene: GearPtr );
	{ Prepare the mission. Basically, this just involves initializing the }
	{ cash payout counter. }
var
	F,TL,PayRate: LongInt;
	M: GearPtr;
	Desc: String;
begin
	TL := HQRenown( HQCamp );
	PayRate := NAttValue( Scene^.NA , NAG_ArenaMissionInfo , NAS_PayRate );
	if PayRate = 0 then PayRate := 400;
	SetNAtt( Scene^.NA , NAG_ArenaMissionInfo , NAS_Pay , Calculate_Reward_Value( Nil , Calculate_Threat_Points( TL , 100 ) , PaYRate ) );
	SetSAtt( Scene^.SA , 'name <>' );
	Desc := SAttValue( Scene^.SA , 'TYPE' ) + ' ' + DifficulcyContext( TL );
	SetSAtt( Scene^.SA , 'TYPE <' + Desc + '>' );

	{ Prep the NPCs to the correct level. }
	M := Scene^.InvCom;
	while M <> Nil do begin
		if M^.G = GG_Character then begin
			{ Set the faction. }
			F := NAttValue( M^.NA , NAG_Personal , NAS_FactionID );
			if F < 0 then SetNAtt( M^.NA , NAG_Personal , NAS_FactionID , ElementID( Scene , Abs( F ) ) );
			SetSkillsAtLevel( M , TL );
		end;
		M := M^.Next;
	end;
end;

Function NumMissions( HQCamp: CampaignPtr ): Integer;
	{ Return the number of missions currently waiting for the PC. }
var
	M: GearPtr;
	N: Integer;
begin
	N := 0;
	M := HQCamp^.Source^.InvCom;
	while M <> Nil do begin
		if M^.G = GG_Scene then Inc( N );
		M := M^.Next;
	end;
	NumMissions := N;
end;

Function GetMission( HQCamp: CampaignPtr; N: Integer ): GearPtr;
	{ Retrieve mission N. }
var
	it,M: GearPtr;
begin
	M := HQCamp^.Source^.InvCom;
	it := Nil;
	while ( M <> Nil ) and ( it = Nil ) do begin
		if M^.G = GG_Scene then begin
			Dec( N );
			if N = 0 then it := M;
		end;
		M := M^.Next;
	end;
	GetMission := it;
end;

Procedure AddMissions( HQCamp: CampaignPtr; N: Integer );
	{ Refresh the missions. Yay! Basically make sure there are five missions to }
	{ choose between. }
var
	HQContext: String;
	Arena_Mission_Master_List,M,Fac: GearPtr;
	ShoppingList: NAttPtr;
begin
	{ Load the missions from disk. }
	{ I load them each time this procedure is called to make sure the NPCs }
	{ and other things are randomized correctly; also so I can make changes }
	{ to the mission lists while playing without restarting. }
	Arena_Mission_Master_List := AggregatePattern( 'ARENAMISSION_*.txt' , Series_Directory );

	{ Start by determining the arena unit's context. This is determied by the }
	{ current faction being fought for plus the arena unit's renown. }
	Fac := SeekCurrentLevelGear( HQCamp^.Source^.InvCom , GG_Faction , NAttValue( HQCamp^.Source^.NA , NAG_Personal , NAS_FactionID ) );
	if Fac <> Nil then begin
		HQContext := SAttValue( Fac^.SA , 'TYPE' ) + ' ' + SAttValue( Fac^.SA , 'DESIG' );
	end else begin
		HQContext := 'FDFOR MILITARY';
	end;
	HQContext := HQContext + ' ' + DifficulcyContext( NAttValue( HQCamp^.Source^.NA , NAG_CharDescription , NAS_Renowned ) );

	{ Next create the list of potential content to add. }
	ShoppingList := CreateComponentList( Arena_Mission_Master_List , HQContext );

	while ( ShoppingList <> Nil ) and ( N > 0 ) do begin
		M := CloneGear( SelectComponentFromList( Arena_Mission_Master_List , ShoppingList ) );
		if InsertArenaMission( HQCamp^.Source , M ) then begin
			Dec( N );
		end;
	end;

	DisposeNAtt( ShoppingList );
	DisposeGear( Arena_Mission_Master_List );
end;

Procedure UpdateMissions( HQCamp: CampaignPtr );
	{ Check to see if there are enough missions. Maybe delete some of them. }
	{ Bring the total back to max. }
var
	N: Integer;
	M: GearPtr;
begin
	{ Step one- delete some missions at random. }
	N := NumMissions( HQCamp );
	Repeat
		if N > 1 then begin
			M := GetMission( HQCamp , Random( N ) + 1 );
			if M <> Nil then RemoveGear( HQCamp^.Source^.InvCom , M );
		end;
		Dec( N );
	until ( N < 1 ) or ( Random( 3 ) <> 1 );

	{ Step two- make sure we have enough missions. }
	AddMissions( HQCamp , HQMaxMissions( HQCamp ) - NumMissions( HQCamp ) );
end;

Procedure ClearWeaponRecharge( LList: GearPtr );
	{ To prevent strange bugs from happening, clear all weapon recharge times }
	{ upon leaving combat. }
begin
	while LList <> Nil do begin
		SetNAtt( LList^.NA , NAG_WeaponModifier , NAS_Recharge , 0 );
		ClearWeaponRecharge( LList^.InvCom );
		ClearWeaponRecharge( LList^.SubCom );
		LList := LList^.Next;
	end;
end;

Procedure PostMissionCleanup( HQCamp: CampaignPtr; PCForces: GearPtr );
	{ After a battle is over, deal with the survivors. There are survivors? }
	{ I must not have made the mission hard enough... }
var
	PC: GearPtr;
	Cost: LongInt;
begin
	{ To start with, recharge/repair everyone in the list. }
	{ We'll make three passes: First, "repair" all characters. }
	{ Second, repair all mecha. Third, restock all mecha and characters. }

	{ First pass- medical attention for characters. }
	PC := PCForces;
	while PC <> Nil do begin
		{ Status effects get repaired for free- otherwise, a low-on-cash }
		{ arena unit could enter the next battle with a mecha still on fire from their }
		{ last battle, and that would suck. Also remove conditions now, since }
		{ everybody needs that done. }
		StripNAtt( PC , NAG_StatusEffect );
		StripNAtt( PC , NAG_Condition );
		ClearWeaponRecharge( PC^.SubCom );
		ClearWeaponRecharge( PC^.InvCom );

		if PC^.G = GG_Character then begin
			Cost := AHQRepairCost( HQCamp , PC );
			if ( Cost > 0 ) and ( HQCash( HQCamp ) >= Cost ) then begin
				DoFullRepair( HQCamp , PC );
			end;
		end;

		PC := PC^.Next;
	end;

	{ Second pass- repair all mecha. }
	PC := PCForces;
	while PC <> Nil do begin
		if PC^.G = GG_Mecha then begin
			Cost := AHQRepairCost( HQCamp , PC );
			if ( Cost > 0 ) and ( HQCash( HQCamp ) >= Cost ) then begin
				DoFullRepair( HQCamp , PC );
			end;
		end;

		PC := PC^.Next;
	end;

	{ Third pass- reload all weapons. }
	PC := PCForces;
	while PC <> Nil do begin
		Cost := ReloadMasterCost( PC );
		if ( Cost > 0 ) and ( HQCash( HQCamp ) >= Cost ) then begin
			ArenaReloadMaster( HQCamp , PC );
		end;
		PC := PC^.Next;
	end;

	{ Once that's been taken care of, stick the PCs back in the unit. }
	InsertSubCom( HQCamp^.Source , PCForces );

	{ Finally update the missions. }
	UpdateMissions( HQCamp );
end;

Procedure AddDamageReloadStatus( HQCamp: CampaignPtr; M: GearPtr; var msg: String );
	{ If this model needs repairs or reloading, indicate that here. }
var
	POK: Integer;	{ Percent OK }
begin
	if AHQRepairCost( HQCamp ,  M ) > 0 then begin
		POK := PercentDamaged( M );
		if POK = 100 then POK := 99;
		msg := msg + ' (%' + BStr( POK ) + ')';
	end;
	if ReloadMasterCost( M ) > 0 then msg := msg + ' -ammo-';
end;

Function AHQMechaName( HQCamp: CampaignPtr; Mek: GearPtr ): String;
	{ Return the name of this mecha along with its pilot. }
	{ If the mecha's pilot can't be found, clear the PILOT string attribute. }
var
	name,pname: String;
	Pilot: GearPtr;
begin
	name := FullGearName( Mek );
	pname := SAttValue( Mek^.SA , 'pilot' );
	if pname <> '' then begin
		Pilot := SeekGearByName( HQCamp^.Source^.SubCom , pname );
		if Pilot = Nil then begin
			{ Oops, no pilot. Must have died or been removed }
			{ from the unit. Fix this mecha's data. }
			SetSatt( Mek^.SA , 'pilot <>' );
		end else begin
			{ Pilot has been found. Add to the name. }
			name := name + ' [' + pname + ']';
		end;
	end;
	AddDamageReloadStatus( HQCamp , Mek , name );
	AHQMechaName := name;
end;

Procedure UpdatePilotMechaMenus( HQCamp: CampaignPtr );
	{ Add the pilots and the mecha to their respective menus. }
	{ If any mecha/pilot matchups are invalid, clear them. }
	{ This is done via the above function, BTW. }
var
	N,PMI,MMI: Integer;
	M: GearPtr;
	name: String;
begin
	{ If either of the menus currently exist, dispose of them. }
	if ADR_PilotMenu <> Nil then begin
		PMI := ADR_PilotMenu^.selectitem;
		DisposeRPGMenu( ADR_PilotMenu );
	end else begin
		PMI := 1;
	end;
	if ADR_MechaMenu <> Nil then begin
		MMI := ADR_MechaMenu^.selectitem;
		DisposeRPGMenu( ADR_MechaMenu );
	end else begin
		MMI := 1;
	end;

	{ Allocate the menus. }
	ADR_PilotMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaPilotMenu );
	ADR_MechaMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

	{ Go through the unit contents, adding to whichever menu is appropriate. }
	M := HQCamp^.Source^.SubCom;
	N := 1;
	while M <> Nil do begin
		if M^.G = GG_Character then begin
			name := GearName( M );
			AddDamageReloadStatus( HQCamp , M , name );
			AddRPGMenuItem( ADR_PilotMenu , name , N );
		end else if M^.G = GG_Mecha then begin
			{ For a mecha, add not just the mecha's name but also the }
			{ pilot's name. If no pilot can be found, clean up that mess. }
			name := AHQMechaName( HQCamp , M );
			AddRPGMenuItem( ADR_MechaMenu , name , N );
		end else begin
			AddRPGMenuItem( ADR_MechaMenu , '*' + GearName( M ) , N );
		end;

		Inc( N );
		M := M^.Next;
	end;

	{ Sort the menus. }
	RPMSortAlpha( ADR_PilotMenu );
	RPMSortAlpha( ADR_MechaMenu );
	SetItemByPosition( ADR_PilotMenu , PMI );
	SetItemByPosition( ADR_MechaMenu , MMI );
end;

Procedure StripAllMecha( var PC: GearPtr );
	{ We've been provided with a linked list. Remove everything }
	{ that isn't a mecha. }
var
	Mek,M2: GearPtr;
	Total: LongInt;
begin
	Mek := PC;
	Total := 0;
	while Mek <> Nil do begin
		M2 := Mek^.Next;
		if Mek^.G <> GG_Character then begin
			Total := Total + GearValue( Mek );
			RemoveGear( PC , Mek );
		end;
		Mek := M2;
	end;
	if ( PC <> Nil ) and ( PC^.Next = Nil ) then AddNAtt( PC^.NA , NAG_Experience, NAS_Credits , Total );
end;


{ *** USER INTERFACE BITS *** }

procedure AddPilotToUnit( HQCamp: CampaignPtr );
	{ Browse the disk for a character file. If one is selected, }
	{ display the character's stats and ask whether or not to hire }
	{ this character. If hired, add the character to the unit, }
	{ save the game, then delete the character's individual file. }
	Function HiringPrice( PC: GearPtr ): LongInt;
		{ Return the price of recruiting this character into the unit. }
	begin
		HiringPrice := GearValue( PC );
	end;
	Function IChooseYou( PC: GearPtr ): Boolean;
		{ Maybe add this character to the unit. This is going to cost }
		{ money, so maybe not. }
	var
		YNMenu: RPGMenuPtr;
		cost: LongInt;
		ISaidYes: Boolean;
	begin
		{ Create the menu. }
		YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
		cost := HiringPrice( PC );
		if HQCash( HQCamp ) >= cost then begin
			AddRPGMenuItem( YNMenu , MsgString( 'ARENA_APTU_Yes' ) + ' ($' + BStr( cost ) + ')' , 1 );
			AddRPGMenuItem( YNMenu , MsgString( 'ARENA_APTU_No' ) , -1 );
		end else begin
			AddRPGMenuItem( YNMenu , MsgString( 'ARENA_APTU_TooExpensive' ) , -1 );
		end;
		ADR_Source := PC;

		if SelectMenu( YNMenu , @DoPurchaseRedraw ) = 1 then begin
			ISaidYes := True;
		end else begin
			ISaidYes := False;
		end;

		{ Get rid of the Yes/No menu. }
		DisposeRPGMenu( YNMenu );

		IChooseYou := ISaidYes;
	end;
var
	PCList,PC: GearPtr;
	PCMenu: RPGMenuPtr;
	FList,FName: SAttPtr;
	F: Text;
	N: Integer;
begin
	DialogMSG( MsgString( 'ARENA_APTU_Prompt' ) );

	{ Build the character list. Filter out any characters that can't be added }
	{ to the unit. }
	FList := CreateFileList( Save_Character_Base + Default_Search_Pattern );
	PCList := Nil;

	FName := FList;
	while FName <> Nil do begin
		Assign( F , Save_Game_Directory + FName^.info );
		reset(F);
		PC := ReadCGears(F);
		Close(F);

		StripAllMecha( PC );
		SetSAtt( PC^.SA , 'filename <' + FName^.Info + '>' );
		AppendGear( PCList , PC );

		FName := FName^.Next;
	end;
	DisposeSAtt( FList );

	{ Keep querying for characters until cancel is selected. }
	repeat
		{ Create the PC menu. }
		PCMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
		BuildSiblingMenu( PCMenu , PCList );
		RPMSortAlpha( PCMenu );
		AlphaKeyMenu( PCMenu );
		AddRPGMenuItem( PCMenu , MsgString( 'Exit' ) , -1 );

		{ Select a file, then dispose of the menu. }
		{ Don't need to worry about the menu being empty because }
		{ of the EXIT item. }
		ADR_Source := PCList;
		ADR_SourceMenu := PCMenu;
		N := SelectMenu( PCMenu , @PurchaseHardwareRedraw );
		DisposeRPGMenu( PCMenu );

		{ If a file was selected, load it and see if the player }
		{ wants to keep it. }
		if N > 0 then begin

			PC := RetrieveGearSib( PCList , N );
			DelinkGear( PCList , PC );

			{ Ask the player what to do with this character. }
			if IChooseYou( PC ) then begin
				{ Add the character to the unit. }
				InsertSubCom( HQCamp^.Source , PC );

				{ Saving the game is done before deleting }
				{ the character file so that if there's a }
				{ problem in saving, at least the original }
				{ character file will be intact. }
				PCSaveCampaign( HQCamp , Nil , False );
				Assign( F , Save_Game_Directory + SAttValue( PC^.SA , 'filename' ) );
				Erase(F);

				{ Update the menus here. }
				UpdatePilotMechaMenus( HQCamp );
			end else begin
				{ Stick this character back in the list. }
				AppendGear( PCList , PC );
			end;
		end;
	until N = -1;

	DisposeGear( PCList );
end;

procedure PurchaseGear( HQCamp: CampaignPtr; Part: GearPtr );
	{ The unit may or may not want to buy PART. }
	{ Show the price of this gear, and ask whether or not the }
	{ player wants to make this purchase. }
var
	YNMenu: RPGMenuPtr;
	Cost: LongInt;
begin
	Cost := ModifiedCost( HQCamp , GearValue( Part ) , NAS_Shopping );

	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	AddRPGMenuItem( YNMenu , ReplaceHash( MsgString( 'ARENA_PurchaseYes' ) , GearName( Part ) ) + ' ($' + BStr( Cost ) + ')' , 1 );
	AddRPGMenuItem( YNMenu , MsgSTring( 'ARENA_PurchaseNo' ) , -1 );

	ADR_Source := Part;

	if SelectMenu( YNMenu , @DoPurchaseRedraw ) = 1 then begin
		if NAttValue( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
			{ Copy the gear, then stick it in inventory. }
			Part := CloneGear( Part );
			InsertSubCom( HQCamp^.Source , Part );

			{ Reduce the buyer's cash by the cost of the gear. }
			AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , -Cost );

			DialogMSG( ReplaceHash( MsgString( 'ARENA_PurchaseComplete' ) , GearName( Part ) ) );
		end else begin
			{ Not enough cash to buy... }
			DialogMSG( ReplaceHash( MsgString( 'ARENA_PurchaseFail' ) , GearName( Part ) ) );
		end;
	end;

	DisposeRPGMenu( YNMenu );
end;

procedure PurchaseHardware( HQCamp: CampaignPtr );
	{ Create a list of mecha which are within this unit's price }
	{ range, then allow the user to browse the list and maybe }
	{ purchase some. }
var
	MekList: GearPtr;
	MekMenu: RPGMenuPtr;
	m1,mek: GearPtr;	{ The start of the mecha file, }
			{ and the mek being considered for purchase. }
	N: Integer;
	Factions,DefaultColors: String;
begin
	{ Create the list of mecha that can be purchased. }
	MekList := AggregatePattern( '*.txt' , Design_Directory );

	{ Create the list of factions that mecha can be purchased from. }
	Factions := 'GENERAL';
	mek := SeekCurrentLevelGear( HQCamp^.Source^.InvCom , GG_Faction , HQFac( HQCamp ) );
	if mek <> Nil then begin
		Factions := Factions + ' ' + SAttValue( mek^.SA , 'DESIG' );
		DefaultColors := 'SDL_COLORS <' + SAttValue( mek^.SA , 'mecha_colors' ) + '>';
	end else begin
		DefaultColors := 'SDL_COLORS <66 121 179 210 215 80 205 25 0>';
	end;

	{ Remove non-mecha, expensive mecha, and extra-factional mecha. }
	{ I don't think extra-factional is a word, but it's 1:30 at night and you know what I mean. }
	mek := MekList;
	while mek <> Nil do begin
		M1 := mek^.Next;
		{ If it doesn't fit, remove it. }
		if ( Mek^.G <> GG_Mecha ) or ( ModifiedCost( HQCamp , GearValue( Mek ) , NAS_Shopping ) > HQCash( HQCamp ) ) or not MechaMatchesFaction( Mek , Factions ) then RemoveGear( MekList , Mek )
		{ If it does fit, paint it. }
		else SetSAtt( Mek^.SA , DefaultColors );
		mek := M1;
	end;

	{ Create the mecha menu. }
	MekMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	BuildSiblingMenu( MekMenu , MekList );
	RPMSortAlpha( MekMenu );
	AddRPGMenuItem( MekMenu , MsgString( 'Exit' ) , -1 );

	repeat
		ADR_Source := MekList;
		ADR_SourceMenu := MekMenu;

		{ Prompt the user for a file selection. }
		N := SelectMenu( MekMenu , @PurchaseHardwareRedraw );

		if N > 0 then begin
			Mek := RetrieveGearSib( MekList , N );
			PurchaseGear( HQCamp , Mek );
			UpdatePilotMechaMenus( HQCamp );
		end;
	until N = -1;

	{ Get rid of dynamic resources. }
	DisposeRPGMenu( MekMenu );
	DisposeGear( MekList );
end;

Procedure ViewMecha( HQCamp: CampaignPtr; PC: GearPtr );
	{ Examine this mecha. Call up a menu with options related to this }
	{ character. }
	Procedure SellMecha( SalePrice: LongInt );
		{ This mecha should be removed from the unit, and some cash gained. }
	begin
		DialogMsg( ReplaceHash( MsgString( 'ARENA_VMEK_SMI_SellItem' ) , GearName( PC ) ) );
		RemoveGear( HQCamp^.Source^.SubCom , PC );
		AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , SalePrice );
		PCSaveCampaign( HQCamp , Nil , False );
	end;
	Procedure AssignPilotForMecha;
		{ Select a pilot for this mecha, then associate the two. }
	var
		Mek: GearPtr;
		N: Integer;
	begin
		DialogMSG( ReplaceHash( MsgString( 'ARENA_VMEK_APFM_SelectPilot' ) , GearName( PC ) ) );

		ADR_Source := HQCamp^.Source^.SubCom;
		ADR_SourceMenu := ADR_PilotMenu;
		AddRPGMenuItem( ADR_PilotMenu , MsgString( 'CANCEL' ) , -1 );

		N := SelectMenu( ADR_PilotMenu , @ViewPilotRedraw );

		if ( N <> -1 ) then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek <> Nil then begin
				AssociatePilotMek( HQCamp^.Source^.SubCom , Mek , PC );
			end;
		end;

		{ Update the display. }
		UpdatePilotMechaMenus( HQCamp );
	end;
	Function InventoryValue: LongInt;
		{ Return the value of all gears in this mecha's general }
		{ inventory. }
	var
		I: GearPtr;
		Total: LongInt;
	begin
		I := PC^.InvCom;
		Total := 0;
		while I <> Nil do begin
			Total := Total + GearValue( I );
			I := I^.Next;
		end;
		InventoryValue := Total div 10;
	end;
	Procedure SellMechaInventory;
		{ This mecha's inventory should be deleted, and some cash gained. }
	var
		I: GearPtr;
	begin
		AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , InventoryValue );
		while PC^.InvCom <> Nil do begin
			I := PC^.InvCom;
			DialogMsg( ReplaceHash( MsgString( 'ARENA_VMEK_SMI_SellItem' ) , GearName( I ) ) );
			RemoveGear( PC^.InvCom , I );
		end;
		PCSaveCampaign( HQCamp , Nil , False );
	end;
var
	RPM: RPGMenuPtr;
	N: Integer;
	SalePrice,Cost: LongInt;
begin
	{ The sale price is 25% of the original price times the damage status, in order }
	{ to prevent shop-scumming. }
	SalePrice := GearValue( PC ) div 10;
	repeat
		ADR_Source := PC;

		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

		AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_AssignPilot' ) , 1 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_ViewInventory' ) , 5 );
		if HasSkill( HQCamp^.Source , NAS_MechaEngineering ) then AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_EditParts' ) , 6 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_SellMecha' ) + ' ($' + BStr( SalePrice ) + ')' , -2 );
		if PC^.InvCom <> Nil then AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_SellMechaInv' ) + ' ($' + BStr( InventoryValue ) + ')' , 4 );
		Cost := AHQRepairCost( HQCamp ,  PC );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_RepairUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 2 );
		end;

		Cost := ReloadMasterCost( PC );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_ReloadUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 3 );
		end;

		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

		N := SelectMenu( RPM , @ViewSourceMechaRedraw );
		DisposeRPGMenu( RPM );

		case N of
			1:	AssignPilotForMecha;
			2:	DoFullRepair( HQCamp , PC );
			3:	ArenaReloadMaster( HQCamp , PC );
			4:	SellMechaInventory;
			5:	ArenaHQBackpack( HQCamp^.Source , PC , @BasicArenaRedraw );
			6:	MechaPartEditor( Nil , HQCamp^.Source^.SubCom , HQCamp^.Source , PC , @BasicArenaRedraw );
			-2:	SellMecha( SalePrice );
		end;
	until N < 0;
end;

Procedure ViewItem( HQCamp: CampaignPtr; Part: GearPtr );
	{ Examine this item. Call up a menu with options related to it. }
	Procedure SellItem( SalePrice: LongInt );
		{ This item should be removed from the unit, and some cash gained. }
	begin
		DialogMsg( ReplaceHash( MsgString( 'ARENA_VMEK_SMI_SellItem' ) , GearName( Part ) ) );
		RemoveGear( HQCamp^.Source^.SubCom , Part );
		AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , SalePrice );
		PCSaveCampaign( HQCamp , Nil , False );
	end;
	Procedure GiveItemToTeamMate;
		{ Give this item to whoever can hold it. }
	var
		RPM: RPGMenuPtr;
		Mek: GearPtr;
		N: Integer;
	begin
		{ Start by allocating the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

		{ Add all the whoevers that might be able to accept this item. }
		Mek := HQCamp^.Source^.SubCom;
		N := 1;
		while Mek <> Nil do begin
			if IsLegalInvCom( Mek , Part ) and ( Mek <> Part ) then begin
				AddRPGMenuItem( RPM , AHQMechaName( HQCamp , Mek ) , N );
			end;
			Inc( N );
			Mek := Mek^.Next;
		end;

		{ Select an item from the menu. }
		if RPM^.NumItem > 0 then begin
			DialogMsg( ReplaceHash( MsgString( 'ARENA_VITEM_GiveItem_Prompt' ) , GearName( Part ) ) );
			ADR_Source := HQCamp^.Source^.SubCom;
			ADR_SourceMenu := RPM;
			N := SelectMenu( RPM , @ViewMechaRedraw );
		end else begin
			N := -1;
		end;
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek <> Nil then begin
				DelinkGear( HQCamp^.Source^.SubCom , Part );
				InsertInvCom( Mek , Part );
			end;
		end;
	end;
var
	RPM: RPGMenuPtr;
	N: Integer;
	SalePrice,Cost: LongInt;
begin
	{ The sale price is 25% of the original price times the damage status, in order }
	{ to prevent shop-scumming. }
	SalePrice := GearValue( Part ) div 10;
	repeat
		ADR_Source := Part;

		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

		AddRPGMenuItem( RPM , MsgString( 'ARENA_VItem_SellItem' ) + ' ($' + BStr( SalePrice ) + ')' , -2 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VItem_GiveItem' ) , -3 );

		Cost := AHQRepairCost( HQCamp ,  Part );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_RepairUnit' ) , GearName( Part ) ) + ' ($' + BStr( Cost ) + ')' , 2 );
		end;

		Cost := ReloadMasterCost( Part );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_ReloadUnit' ) , GearName( Part ) ) + ' ($' + BStr( Cost ) + ')' , 3 );
		end;

		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

		N := SelectMenu( RPM , @ViewSourceMechaRedraw );
		DisposeRPGMenu( RPM );

		case N of

			2:	DoFullRepair( HQCamp , Part );
			3:	ArenaReloadMaster( HQCamp , Part );

			-2:	SellItem( SalePrice );
			-3:	GiveItemToTeamMate;
		end;
	until N < 0;
end;

procedure ExamineMecha( HQCamp: CampaignPtr );
	{ Examine the unit's mecha, and do any mecha-related things }
	{ that need doing. }
var
	N: Integer;
	Mek: GearPtr;
begin
	repeat
		UpdatePilotMechaMenus( HQCamp );
		AddRPGMenuItem( ADR_MechaMenu , MsgString( 'EXIT' ) , -1 );

		ADR_SourceMenu := ADR_MechaMenu;
		ADR_Source := HQCamp^.Source^.SubCom;
		N := SelectMenu( ADR_MechaMenu , @ViewMechaRedraw );

		if N > 0 then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek^.G = GG_Mecha then begin
				ViewMecha( HQCamp , Mek );
			end else begin
				ViewItem( HQCamp , Mek );
			end;
		end;

	until N = -1;
end;

Procedure ViewCharacter( HQCamp: CampaignPtr; PC: GearPtr );
	{ Examine this character. Call up a menu with options related to this }
	{ character. }
	Procedure RemoveCharacter;
		{ This character should be delinked from the unit and saved to disk. }
	begin
		DelinkGear( HQCamp^.Source^.SubCom , PC );
		SaveChar( PC );
		PCSaveCampaign( HQCamp , Nil , False );
		DisposeGear( PC );
	end;
	Procedure AssignMechaForPilot;
		{ Select a mecha for this pilot, then associate the two. }
	var
		Mek: GearPtr;
		N: Integer;
	begin
		DialogMSG( ReplaceHash( MsgString( 'ARENA_VCHAR_AMFP_SelectMecha' ) , GearName( PC ) ) );

		ADR_Source := HQCamp^.Source^.SubCom;
		ADR_SourceMenu := ADR_MechaMenu;
		AddRPGMenuItem( ADR_MechaMenu , MsgString( 'CANCEL' ) , -1 );

		N := SelectMenu( ADR_MechaMenu , @ViewMechaRedraw );

		if ( N <> -1 ) then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek <> Nil then begin
				AssociatePilotMek( HQCamp^.Source^.SubCom , PC , Mek );
			end;
		end;

		{ Update the display. }
		UpdatePilotMechaMenus( HQCamp );
	end;

var
	RPM: RPGMenuPtr;
	N: Integer;
	Cost: LongInt;
begin
	repeat
		ADR_Source := PC;

		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaPilotMenu );

		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_DoTraining' ) , 4 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_ViewInventory' ) , 5 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_AssignMecha' ) , 1 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_RemoveCharacter' ) , -2 );
		Cost := AHQRepairCost( HQCamp ,  PC );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_RepairUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 2 );
		end;

		Cost := ReloadMasterCost( PC );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_ReloadUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 3 );
		end;

		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

		N := SelectMenu( RPM , @ViewSourcePilotRedraw );
		DisposeRPGMenu( RPM );

		case N of
			1:	AssignMechaForPilot;
			2:	DoFullRepair( HQCamp , PC );
			3:	ArenaReloadMaster( HQCamp , PC );
			4:	DoTraining( Nil , PC , @BasicArenaRedraw );
			5:	ArenaHQBackpack( HQCamp^.Source , PC , @BasicArenaRedraw );
			-2:	RemoveCharacter;
		end;
	until N < 0;
end;

procedure ExamineCharacters( HQCamp: CampaignPtr );
	{ Take a look through this unit's characters. Maybe do stuff to them. }
var
	N: Integer;
begin
	repeat
		UpdatePilotMechaMenus( HQCamp );
		AddRPGMenuItem( ADR_PilotMenu , MsgString( 'EXIT' ) , -1 );

		ADR_SourceMenu := ADR_PilotMenu;
		ADR_Source := HQCamp^.Source^.SubCom;
		N := SelectMenu( ADR_PilotMenu , @ViewPilotRedraw );

		if N > 0 then begin
			ViewCharacter( HQCamp , RetrieveGearSib( HQCamp^.Source^.SubCom , N ) );
		end;

	until N = -1;
end;

Procedure DeliverMissionDebriefing( Adv,Scene: GearPtr );
	{ Deliver any pending news to the player. The big news will be which characters died, }
	{ which ones were rescued by the Medicine skill, which mecha were destroyed, and which }
	{ mecha were returned from the brink. }
	Procedure GiveTheNews( NPC: Integer; const Msg_Key: String; NameList: SAttPtr );
		{ The provided NPC will give the provided message about the provided names. }
	begin
		while NameList <> Nil do begin
			HQMonologue( Adv, NPC , ReplaceHash( ArenaNPCMessage( Adv , NPC , Msg_Key ) , NameList^.Info ) );
			NameList := NameList^.Next;
		end;
	end;
var
	Dead,Healed,Destroyed,Fixed,SList: SAttPtr;	{ The various message classes. }
begin
	Dead := Nil;
	Healed := Nil;
	Destroyed := Nil;
	Fixed := Nil;

	{ Step one: Look for matching messages. }
	SList := Scene^.SA;
	while SList <> Nil do begin
		if HeadMatchesString( ARENAREPORT_CharRecovered , SList^.Info ) then StoreSAtt( Healed , RetrieveAString( SList^.Info ) )
		else if HeadMatchesString( ARENAREPORT_CharDied , SList^.Info ) then StoreSAtt( Dead , RetrieveAString( SList^.Info ) )
		else if HeadMatchesString( ARENAREPORT_MechaRecovered , SList^.Info ) then StoreSAtt( Fixed , RetrieveAString( SList^.Info ) )
		else if HeadMatchesString( ARENAREPORT_MechaDestroyed , SList^.Info ) then StoreSAtt( Destroyed , RetrieveAString( SList^.Info ) );
		SList := SList^.Next;
	end;

	{ Step two: Report the stuff we just found out. }
	GiveTheNews( ANPC_Medic , 'PCHealed' , Healed );
	GiveTheNews( ANPC_Medic , 'PCDead' , Dead );
	GiveTheNews( ANPC_Mechanic , 'MechaFixed' , Fixed );
	GiveTheNews( ANPC_Mechanic , 'MechaDestroyed' , Destroyed );

	DisposeSAtt( Dead );
	DisposeSAtt( Healed );
	DisposeSAtt( Destroyed );
	DisposeSAtt( Fixed );
end;

Procedure DeliverSalvageReport( Adv , PCList: GearPtr );
	{ Report on any salvage recovered from the battle. }
begin
	while PCList <> Nil do begin
		if NAttValue( PCList^.NA , NAG_MissionReport , NAS_WasSalvaged ) <> 0 then begin
			HQMonologue( Adv, ANPC_Supply , ReplaceHash( ArenaNPCMessage( Adv , ANPC_Supply , 'SalvageReport' ) , FullGearName( PCList ) ) );
		end;
		PCList := PCList^.Next;
	end;
end;

Function MissionFrontEnd( HQCamp: CampaignPtr; Scene,PCForces: GearPtr ): Integer;
	{ Play the mission, along with all the needed wrapper stuff. }
	Procedure ReportRenownGain( R0,R1: Integer );
		{ The team has gained some renown. If this causes a change in rank, }
		{ the Intel officer will let the player know. }
		{ R0 is initial renown, R1 is current renown. }
	var
		T,NewRank: Integer;
	begin
		NewRank := 0;
		for t := 1 to 4 do begin
			if ( R1 > ( t * 20 ) ) and ( R0 <= ( t * 20 ) ) then NewRank := T + 1;
		end;
		if NewRank <> 0 then HQMonologue( HQCamp^.Source , ANPC_Intel , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Intel , 'GainPromotion' ) , MsgSTring( 'AHQRANK_' + BStr( NewRank ) ) ) );
	end;
	Procedure ReportRenownLoss( R0,R1: Integer );
		{ Check for the team's rank dropping; if so, report it. }
		{ R0 is initial renown, R1 is current renown. }
	var
		T,NewRank: Integer;
	begin
		NewRank := 0;
		for t := 1 to 4 do begin
			if ( R0 > ( t * 20 ) ) and ( R1 <= ( t * 20 ) ) then NewRank := T;
		end;
		if NewRank <> 0 then HQMonologue( HQCamp^.Source , ANPC_Intel , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Intel , 'LosePromotion' ) , MsgSTring( 'AHQRANK_' + BStr( NewRank ) ) ) );
	end;
var
	N: Integer;
	C0,C1: LongInt;	{ Cash0, Cash1 }
	R0,R1: Integer;	{ Renown0, Renown1 }
begin
	{ Save the initial money and renown. }
	C0 := HQCash( HQCamp );
	R0 := HQRenown( HQCamp );

	N := ScenePlayer( HQCamp , Scene , PCForces );

	{ After the mission is over, deliver any reports. }
	if N <> 0 then begin
		{ The mission has ended properly; it wasn't quit. }
		{ Do the debriefing here. }
		C1 := HQCash( HQCamp );
		if C1 > C0 then begin
			HQMonologue( HQCamp^.Source , ANPC_Commander , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Commander , 'ReportEarnings' ) , BStr( C1 - C0 ) ) );
		end;

		DeliverMissionDebriefing( HQCamp^.Source , Scene );

		DeliverSalvageReport( HQCamp^.Source , PCForces );
	end;

	{ After finishing the battle, get rid of the scene. }
	RemoveGear( HQCamp^.Source^.InvCom , Scene );

	{ Reinsert the surviving PCForces into the unit. }
	PostMissionCleanup( HQCamp , PCForces );

	{ See how much money the repairs/reload cost. }
	if N <> 0 then begin
		C0 := HQCash( HQCamp );
		if C0 < C1 then HQMonologue( HQCamp^.Source , ANPC_Mechanic , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Mechanic , 'ReportExpenses' ) , BStr( C1 - C0 ) ) );

		R1 := HQRenown( HQCamp );
		if R1 > R0 then ReportRenownGain( R0 , R1 )
		else if R1 < R0 then ReportRenownLoss( R0 , R1 );
	end;

	MissionFrontEnd := N;
end;

Function PlayArenaMission( HQCamp: CampaignPtr ): Boolean;
	{ Play an arena mission. Yahoo! }
	{ Return TRUE if the mission was completed, or FALSE if the mission was }
	{ quit in progress. }
	Function SelectAMission: GearPtr;
		{ Select a mission. }
	var
		RPM: RPGMenuPtr;
		N: Integer;
		M: GearPtr;
	begin
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoText );
		AttachMenuDesc( RPM , ZONE_MemoMenu );

		{ Add all the missions to the menu. }
		N := 1;
		M := HQCamp^.Source^.InvCom;
		while M <> Nil do begin
			if M^.G = GG_Scene then begin
				AddRPGMenuItem( RPM , GearName( M ) , N , SAttValue( M^.SA , 'DESC' ) );
				Inc( N );
			end;
			M := M^.Next;
		end;

		RPMSortAlpha( RPM );
		AlphaKeyMenu( RPM );
		AddRPGMenuItem( RPM , MsgString( 'CANCEL' ) , -2 );

		N := SelectMenu( RPM , @SelectAMissionRedraw );
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			M := GetMission( HQCamp , N );
		end else begin
			M := Nil;
		end;
		SelectAMission := M;
	end;
	Function SelectAMForces: GearPtr;
		{ Select a number of pilots for this mission. Only pilots who have }
		{ mecha will be considered. }
	var
		ECM: RPGMenuPtr;
		PCForces,Mek,Pilot: GearPtr;
		N: Integer;
	begin
		PCForces := Nil;
		ADR_NumPilotsSelected := 0;
		ADR_PilotsAllowed := 5;
		Repeat
			{ Create the menu. }
			ECM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoText );
			Mek := HQCamp^.Source^.SubCom;
			N := 1;
			while Mek <> Nil do begin
				if ( Mek^.G = GG_Mecha ) then begin
					Pilot := FindMechasPilot( HQCamp^.Source , Mek );
					if Pilot <> Nil then AddRPGMenuItem( ECM , GearName( Pilot ) + ' [' + GearName( Mek ) + ']' , N );
				end;
				Mek := Mek^.Next;
				Inc( N );
			end;

			RPMSortAlpha( ECM );
			AlphaKeyMenu( ECM );
			AddRPGMenuItem( ECM , MsgString( 'ARENA_SAMF_StartMission' ) , -1 );
			AddRPGMenuItem( ECM , MsgString( 'CANCEL' ) , -2 );

			N := SelectMenu( ECM , @SelectAMForcesRedraw );
			DisposeRPGMenu( ECM );

			if N > -1 then begin
				Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
				Pilot := FindMechasPilot( HQCamp^.Source , Mek );
				DialogMsg( ReplaceHash( MsgString( 'ARENA_SAMF_AddPilot' ) , GearName( Pilot ) ) );
				DelinkGear( HQCamp^.Source^.SubCom , Mek );
				DelinkGear( HQCamp^.Source^.SubCom , Pilot );
				AppendGear( PCForces , Mek );
				AppendGear( PCForces , Pilot );
				inc( ADR_NumPilotsSelected );
			end;
		until ( N < 1 ) or ( ADR_NumPilotsSelected >= ADR_PilotsAllowed );
		if N = -2 then begin
			InsertSubCom( HQCamp^.Source , PCForces );
			PCForces := Nil;
			DialogMsg( MsgString( 'ARENA_SAMF_Cancel' ) );
		end;
		SelectAMForces := PCForces;
	end;
var
	PCForces,Scene: GearPtr;
	N: Integer;
begin
	{ Start by selecting the mission. }
	if NumMissions( HQCamp ) < 1 then AddMissions( HQCamp , HQMaxMissions( HQCamp ) );
	Scene := SelectAMission;
	if Scene = Nil then Exit;

	{ Start by selecting the PCForces. }
	PCForces := SelectAMForces;

	if PCForces <> Nil then begin
		{ Load a scenario. }
		PrepMission( HQCamp , Scene );
		N := MissionFrontEnd( HQCamp , Scene , PCForces );

	end else begin
		{ Selection was cancelled. }
		N := 1;
	end;
	PlayArenaMission := N <> 0;
end;

Procedure CreateNewPilot( Camp: CampaignPtr );
	{ Create a new pilot, and add it to the unit. }
var
	PC: GearPtr;
begin
	PC := CharacterCreator( HQFac( Camp ) );
	if PC <> Nil then begin
		StripAllMecha( PC );
		InsertSubCom( Camp^.Source , PC );
	end;
end;

Procedure CheckFactionsPresent( Adv: GearPtr );
	{ Check to make sure that all of the factions which currently exist are represented }
	{ in this adventure. Update the alliegances as necessary. }
	Procedure ModifyFacRelations( NewFac: GearPtr );
		{ NewFac has just been added to the game. Check through the existing factions, and }
		{ make sure they all have the appropriate reaction score for it. }
	var
		Fac,ProtoFac: GearPtr;
	begin
		Fac := Adv^.InvCom;
		while Fac <> Nil do begin
			if ( Fac^.G = GG_Faction ) and ( NewFac <> Fac ) then begin
				{ We've found a faction, and it's not the new faction. How does }
				{ this faction feel about the new faction? The answer can be found }
				{ in the faction prototype. }
				ProtoFac := SeekCurrentLevelGear( Factions_List , GG_Faction , Fac^.S );
				if ProtoFac <> Nil then begin
					SetNAtt( Fac^.NA , NAG_FactionScore , NewFac^.S , NAttValue( ProtoFac^.NA , NAG_FactionScore , NewFac^.S ) );
				end;
			end;
			Fac := Fac^.Next;
		end;
	end;
var
	FLF,InGameFac: GearPtr;
begin
	{ Start by looking through the Faction List Factions }
	FLF := Factions_List;
	while FLF <> Nil do begin
		InGameFac := SeekCurrentLevelGear( Adv^.InvCom , GG_Faction , FLF^.S );
		if InGameFac = Nil then begin
			{ We don't have this faction in the campaign. Horrors! In order to fix things, }
			{ copy it over, then copy over all the faction relations. }
			InGameFac := CloneGear( FLF );
			InsertInvCom( Adv , InGameFac );
			ModifyFacRelations( InGameFac );
		end;
		FLF := FLF^.Next;
	end;
end;

Procedure CheckFactionPersonalities( Adv: GearPtr );
	{ Check to make sure that the faction personalities are loaded, and that all }
	{ positions are accounted for. }
var
	NPCSet,NPCFile,FacNPCs,NewNPC: GearPtr;
	T: Integer;
begin
	{ Search for the NPC Set. }
	NPCSet := SeekCurrentLevelGear( Adv^.InvCom , GG_Set , GS_CharacterSet );
	if NPCSet = Nil then begin
		{ We don't have a NPCSet. Horrors! Better add one. }
		NPCSet := NewGear( Nil );
		NPCSet^.G := GG_Set;
		NPCSet^.S := GS_CharacterSet;
		InsertInvCom( Adv , NPCSet );

		{ Load the NPC file from disk, and copy over the appropriate NPCs for the adventure faction. }
		NPCFile := LoadFile( 'ARENADATA_Personalities.txt' , Series_Directory );
		FacNPCs := SeekCurrentLevelGear( NPCFile , GG_Set , NAttValue( Adv^.NA , NAG_Personal , NAS_FactionID ) );
		if FacNPCs <> Nil then begin
			{ We found a set containing this faction's members. Move them over to the NPCSet. }
			while FacNPCs^.InvCom <> Nil do begin
				NewNPC := FacNPCs^.InvCom;
				DelinkGear( FacNPCs^.InvCom , NewNPC );
				InsertInvCom( NPCSet , NewNPC );
			end;

		end else begin
			{ We found nothing. Create a bunch of stand-in NPCs. }
			for t := 1 to NumArenaNPCs do begin
				NewNPC := LoadNewNPC( 'CITIZEN' , True );
				SetNAtt( NewNPC^.NA , NAG_Personal , NAS_CID , T );
				InsertInvCom( NPCSet , NewNPC );
			end;
		end;
		DisposeGear( NPCFile );
	end;
end;

Procedure PlayArenaCampaign( Camp: CampaignPtr );
	{ Play this arena campaign. }
var
	N: Integer;
	RPM: RPGMenuPtr;
begin
	{ Set the campaign pointer for redraw purposes. }
	ADR_HQCamp := Camp;

	{  As soon as the campaign has been loaded, do some checks to make sure it has everything }
	{ it needs. These checks are done here so that save files from previous versions will remain }
	{ compatable with the current version. }
	CheckFactionsPresent( Camp^.Source );
	CheckFactionPersonalities( Camp^.Source );

	{ If Camp^.GB exists, then the game was saved in the middle of a battle. }
	{ Handle that battle before heading to the main menu. }
	if Camp^.GB <> Nil then begin
		N := MissionFrontEnd( Camp , Camp^.GB^.Scene , Nil );

		{ If a quit signal was recieved, just exit without going to }
		{ the main menu below. }
		if N = 0 then Exit;
	end else begin
		N := 1;

	end;

	{ Main Menu here }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaInfo );
	AddRPGMenuItem( RPM , MsgSTring( 'ARENA_ExamineCharacters' ) , 5 );
	AddRPGMenuItem( RPM , MsgSTring( 'ARENA_ExamineMecha' ) , 1 );
	AddRPGMenuItem( RPM , MsgSTring( 'ARENA_PurchaseHardware' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'ARENA_HireCharacter' ) , 3 );
	AddRPGMenuItem( RPM , MsgString( 'ARENA_CreateNewCharacter' ) , 4 );
	AddRPGMenuItem( RPM , MsgString( 'ARENA_EnterCombat' ) , 6 );
	AddRPGMenuItem( RPM , MsgString( 'ARENA_ExitToMain' ) , 0 );
	RPM^.mode := RPMNoCancel;

	repeat
		UpdatePilotMechaMenus( Camp );
		N := SelectMenu( RPM , @BasicArenaRedraw );

		Case N of
			1: ExamineMecha( Camp );
			2: PurchaseHardware( Camp );
			3: AddPilotToUnit( Camp );
			4: CreateNewPilot( Camp );
			5: ExamineCharacters( Camp );
			6: if not PlayArenaMission( Camp ) then N := -1;
		end;

	until N < 1;

	{ Save the campaign on the way out. }
	{ Don't save the campaign if the game was saved in combat! }
	if N <> -1 then PCSaveCampaign( Camp , Nil , False );

	{ Dispose of dynamic resources. }
	DisposeRPGMenu( RPM );

	{ Clear the campaign pointer. }
	ADR_HQCamp := Nil;

	{ Also get rid of the two menus. }
	DisposeRPGMenu( ADR_PilotMenu );
	DisposeRPGMenu( ADR_MechaMenu );
end;

Procedure StartArenaCampaign;
	{ Initialize a new Arena campaign and start it. }
	Function SelectAFaction: Integer;
		{ Select a faction for this arena unit. }
	var
		RPM: RPGMenuPtr;
		Fac: GearPtr;
		N: Integer;
	begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaInfo );
		AttachMenuDesc( RPM , ZONE_Dialog );
		RPM^.mode := RPMNoCancel;
		Fac := Factions_List;
		while Fac <> Nil do begin
			if AStringHasBString( SAttValue( Fac^.SA , 'TYPE' ) , 'ARENAOK' ) then begin
				AddRPGMenuItem( RPM , GearName( Fac ) , Fac^.S , SAttValue( Fac^.SA , 'DESC' ) );
			end;
			Fac := Fac^.Next;
		end;
		RPMSortALpha( RPM );
		AlphaKeyMenu( RPM );
		N := SelectMenu( RPM , @BasicArenaRedraw );
		DisposeRPGMenu( RPM );
		SelectAFaction := N;
	end;
var
	Camp: CampaignPtr;
	Factions: GearPtr;
	name: String;
begin
	{ Create the campaign and the adventure. }
	Camp := NewCampaign;
	Camp^.Source := LoadFile( 'arenastub.txt' , Series_Directory );

	{ Insert the factions into the adventure. }
	Factions := AggregatePattern( 'FACTIONS_*.txt' , Series_Directory );
	InsertInvCom( Camp^.Source , Factions );

	{ Select one faction for this unit. }
	SetNAtt( Camp^.Source^.NA , NAG_Personal , NAS_FactionID , SelectAFaction );

	{ Give the new arena unit a name. }
	name := GetStringFromUser( MsgString( 'ARENA_NewArenaName' ) , @BasicArenaRedraw );

	if name <> '' then begin
		{ Store the name. }
		SetSAtt( Camp^.Source^.SA , 'name <' + name + '>' );

		{ Actually play with the new campaign. }
		PlayArenaCampaign( Camp );
	end;

	{ Once we're finished, get rid of the campaign. }
	DisposeCampaign( Camp );
end;

Procedure RestoreArenaCampaign( RDP: RedrawProcedureType );
	{ Load an arena campaign from disk and start it. }
var
	RPM: RPGMenuPtr;
	rpgname: String;	{ Campaign Name }
	Camp: CampaignPtr;
	F: Text;		{ A File }
begin
	{ Create a menu listing all the units in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( RPM , Save_Unit_Base + Default_Search_Pattern );

	{ If any units are found, allow the player to load one. }
	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select campaign file to load.');

		rpgname := SelectFile( RPM , RDP );

		if rpgname <> '' then begin
			Assign(F, Save_Game_Directory + rpgname );
			reset(F);
			Camp := ReadCampaign(F);
			Close(F);
			PlayArenaCampaign( Camp );
			DisposeCampaign( Camp );
		end;
	end;

	DisposeRPGMenu( RPM );
end;

initialization
	{ Set all things to NIL to begin with. }
	ADR_PilotMenu := Nil;
	ADR_MechaMenu := Nil;
	ADR_HQCamp := Nil;

	ANPC_MasterPersona := LoadFile( 'ARENADATA_NPCMessages.txt' , Series_Directory );

finalization

	DisposeGear( ANPC_MasterPersona );

end.

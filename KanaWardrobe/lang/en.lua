local S=KanaWardrobe.Strings
S.PROBE_REPORT_TITLE="Build probe report"
S.NEW_PRESET="New preset"
S.ADDON_NAME="KanaWardrobe"
S.INVALID_NAME="Enter a plain name of 1–48 characters."
S.DUPLICATE_NAME="A preset with this name already exists."
S.DUPLICATE="Duplicate"
S.COPY="copy"
S.BINDING_CONFIRMATION_REQUIRED="Equip this item manually first and accept the game's binding confirmation."
local labels={
 PRESETS="Presets",APPLY="Apply",SAVE="Save",CANCEL="Cancel",CONTINUE="Continue editing",RENAME="Rename",EDIT="Edit",DELETE="Delete",CLOSE="Close",ALL="All",NONE="None",WORN="Worn",MISSING="Missing: %d",EMPTY_LIST="Save part of your equipment as a preset.",
 EDIT_HELP="Select slots to save. A selected empty slot removes its item when applied.",RETURN_NOTE="Save and Cancel both restore your previous equipment.",SAVED_RETURN="Preset saved. Returning your equipment…",PAUSED="Paused. Resume when ready.",RESUME="Resume",RECOVERY="Equipment recovery",RESTORE="Restore equipment",RESTORE_AVAILABLE="Restore available items",KEEP_CURRENT="Keep current equipment",KEEP_WARNING="Your original equipment has not been fully restored. Finish the session and keep what you are wearing?",RECOVERY_HELP="A previous operation is unfinished. Restore the original equipment or explicitly keep the current equipment.",CLOSE_EDITOR="Finish editing?",CLOSE_HELP="Save or discard the preset changes and restore your equipment, or continue editing.",DELETE_TITLE="Delete preset?",DELETE_HELP="Delete “%s”? Saved items stay locked. Unlock them manually if no longer needed.",EXTRAS_TITLE="Apply preset “%s”?",EXTRAS_HELP="Additional changes are required:",EXTRA_REMOVE="%s: %s → backpack — %s",EXTRA_MOVE="%s: %s → %s (source slot vacated) — %s",REASON_twoHanded="space for a two-handed weapon",REASON_mythic="only one mythic item can be worn",REASON_sourceMove="move this exact item to the requested slot",REASON_uniqueEquipped="only one copy of this unique item can be worn",MISSING_HELP="Not in the backpack or worn slots:",RESTORE_MISSING_HELP="These original items will not be restored. The recovery session remains open:",USE_WORN="Use worn item",SAVE_EMPTY="Save empty slot",OMIT_SLOT="Do not save slot",RESOLVE="Resolve missing item",SELECTED_SLOT="Save this slot",HIDE_ITEMS="Hide preset items: %d",HIDE_BYPASS="Preset item hiding is paused while the editor is unfinished.",PRESET_SETS="Preset sets",PERFECTED_PARTS="Perfected parts",SET_ITEMS_MISSING="Some preset items are unavailable in the backpack or worn slots.",SET_DATA_UNAVAILABLE="Set information is unavailable for this preset.",NO_PRESET_SETS="This preset has no set items.",TOOLTIP_PRESETS="Presets: %s",TOOLTIP_OTHER_CHARACTER="%s (%s)",UNKNOWN_PROBLEM="The operation could not finish. Check your equipment and try again.",EMPTY_SELECTION="Select at least one slot.",BUSY="Finish the current operation first.",STATE_applying="Equipping…",STATE_preparingEdit="Preparing editor…",STATE_restoring="Returning equipment…",STATE_confirming="Waiting for confirmation…",STATE_recovery="Equipment recovery is required.",NAME="Preset name",MISSING_EDIT="Edit available items?",MISSING_EDIT_HELP="Missing items remain marked until you explicitly replace, clear, or omit their slots.",
}
for k,v in pairs(labels) do S[k]=v end
S.SLOT_NAMES={"Head","Shoulders","Chest","Hands","Waist","Legs","Feet","Necklace","Ring 1","Ring 2","Main hand · I","Off hand · I","Main hand · II","Off hand · II"}
S.PROBLEMS={invalidName=S.INVALID_NAME,nameTooLong=S.INVALID_NAME,duplicateName=S.DUPLICATE_NAME,bindingConfirmationRequired=S.BINDING_CONFIRMATION_REQUIRED,
 itemMissing="The exact saved item is not in the backpack or worn slots.",cannotLock="This item cannot be locked.",lockFailed="The item lock was not confirmed.",lockConflict="An item saved in a preset was unlocked. Lock it again to continue.",sourceChanged="The item moved or changed. Try again.",itemProtected="This exact item belongs to a preset and must stay locked.",lockPending="Waiting for item locks to be confirmed.",inCombat="Wait until combat ends, then try again.",dead="Revive before changing equipment.",blocking="Release block and try again.",busy=S.BUSY,invalidPreset="The preset is invalid.",presetMissing="This preset no longer exists.",revisionConflict="This preset changed. Reopen it and try again.",invalidSlot="This equipment slot is not supported.",duplicateUid="One item is assigned to several slots.",invalidItem="Saved item information is unavailable.",incompatibleSlot="This item does not fit the selected slot.",insufficientSpace="There is not enough free backpack space.",notEquipable="This item cannot currently be equipped.",slotUnavailable="This equipment slot is unavailable.",mythicConflict="Several mythic items are selected.",uniqueEquippedConflict="Several copies of a unique item are selected.",weaponConflict="The selected weapons cannot be worn together.",unplannable="The equipment changes cannot be completed safely.",externalChange="Equipment changed during the operation. Check it before resuming.",requestError="The game did not accept the equipment request.",requestRejected="The equipment request was rejected.",requestTimeout="The equipment request timed out. Its result must be checked before retrying.",sheathTimeout="Could not confirm sheathing weapons. Try again.",stalePlan="Equipment changed. Try the action again.",targetMismatch="The resulting equipment differs from the requested equipment.",stopped="The operation was stopped.",sceneHidden="The inventory was closed. The operation is paused.",missingUnresolved="Resolve each missing item before saving.",noSelection=S.EMPTY_SELECTION,emptySelection=S.EMPTY_SELECTION,setDataUnavailable=S.SET_DATA_UNAVAILABLE,notEditing="Open the editor first.",paused=S.PAUSED,invalidNameType=S.INVALID_NAME}
for _,key in ipairs({"invalidIntent","invalidMode","invalidPlan","invalidSnapshot","invalidState","invalidStep"}) do S.PROBLEMS[key]="Equipment data is invalid. Reopen the inventory and try again." end
S.PROBLEMS.progressObserverError="The operation was interrupted while tracking its progress. Check your equipment before resuming."
local sessionProblems={noSlotsSelected=S.EMPTY_SELECTION,unresolvedMissing="Resolve each missing item before saving.",invalidMissingChoice="Choose how to handle this missing item.",replacementRequired="Equip a replacement in this slot first.",emptyRequired="Remove the worn item from this slot first.",confirmationChanged="The required changes have changed. Review the new confirmation.",recoveryRequired="Restore the unfinished equipment session first.",pendingRequest="A previous equipment request is still unconfirmed. Check the result before retrying.",originalItemsMissing="Some original items are unavailable. Review the list before restoring only available items.",partialRestore="Available items were restored. Some original items remain missing; recovery is still open.",invalidJournal="The saved recovery record is invalid. Check your equipment and explicitly choose to keep it.",invalidRecoveryAction="Choose a recovery action."}
for k,v in pairs(sessionProblems)do S.PROBLEMS[k]=v end
S.OUTCOME_applied="Preset applied."
S.OUTCOME_saved="Preset saved. Previous equipment restored."
S.OUTCOME_cancelled="Editing cancelled. Previous equipment restored."
S.OUTCOME_keptCurrent="Session finished. Current equipment kept."
S.OUTCOME_interruptedApply="The previous application was interrupted. You can select a preset again."
S.PROBLEMS.recoveryChanged="The build state changed after it was checked. Reopen recovery actions and choose an action again."
S.PROBLEMS.commitObserverError="Saving could not finish. Check the preset status and choose how to recover your equipment."
S.STATE_idle="Ready."
S.STATE_editing="Editing preset."
KanaWardrobe.Strings.PRESET_SUMMARY="Preset summary"
KanaWardrobe.Strings.SUMMARY_ARMOR="Armor"
KanaWardrobe.Strings.SUMMARY_ENCHANTS="Enchantments"
KanaWardrobe.Strings.SUMMARY_TRAITS="Traits"

KanaWardrobe.Strings.SUMMARY_FRONT="Main bar"
KanaWardrobe.Strings.SUMMARY_BACK="Backup bar"
KanaWardrobe.Strings.SUMMARY_ITEMS="items"

KanaWardrobe.Strings.SUMMARY_COMPOSITION="Composition"
KanaWardrobe.Strings.SUMMARY_BAR_LEGEND="I · Main   |   II · Backup"

KanaWardrobe.Strings.QUICK_PRESET="Quick snapshot"
KanaWardrobe.Strings.QUICK_SAVE="Save"
KanaWardrobe.Strings.QUICK_LOAD="Load"
KanaWardrobe.Strings.QUICK_SAVE_HELP="Save current equipment to the quick slot, replacing its previous contents. Empty slots are saved too."
KanaWardrobe.Strings.QUICK_LOAD_HELP="Equip the quick snapshot. It stays saved until you overwrite it."
KanaWardrobe.Strings.QUICK_EMPTY="Save equipment to the quick slot first."
KanaWardrobe.Strings.OUTCOME_quickSaved="Equipment saved to the quick slot."
KanaWardrobe.Strings.CAPACITY_HIDDEN="(hidden: %d)"

do
 local S=KanaWardrobe.Strings
 S.BUILD_EMPTY="empty"
 S.BUILD_ABILITY_EXTRA="%s — bar %s, slot %d: %s → %s"
 S.PROBLEMS.invalidBuildSnapshot="Missing actual build or budget facts."
 S.PROBLEMS.attributesUnavailable="Attributes are unavailable."
 S.PROBLEMS.skillsUnavailable="Skills are unavailable."
 S.PROBLEMS.insufficientAttributePoints="Insufficient attribute points."
 S.PROBLEMS.insufficientSkillPoints="Insufficient skill points."
 S.PROBLEMS.insufficientMasteryPoints="Insufficient Class Mastery points."
 S.PROBLEMS.equipmentOverride="Ultimate is overridden by equipment. Remove Cryptcanon manually before changing it."
 S.PROBLEMS.confirmedBuildMismatch="Actual build does not match the confirmed phase."
 S.PROBLEMS.buildDependenciesChanged="Build dependencies changed; review consent again."
end

KanaWardrobe.Strings.BUILD_DEFICIT="Required %d, available %d, deficit %d."

do
 local S=KanaWardrobe.Strings
 S.PROBLEMS.skillUnavailable="The skill or progression is unavailable."
 S.PROBLEMS.skillImmutable="This skill cannot be changed."
 S.PROBLEMS.skillMorphLocked="The requested morph is locked."
 S.PROBLEMS.skillRankLocked="The requested rank is locked."
 S.PROBLEMS.skillMorphMismatch="The bar morph conflicts with the final skill morph."
 S.PROBLEMS.skillBarType="The ability does not fit this action slot."
 S.PROBLEMS.duplicateBarSkill="The same skill is assigned twice on one bar."
 S.PROBLEMS.skillBarLocked="An affected action slot is locked."
 S.PROBLEMS.skillBarOverride="An affected action slot is overridden or immutable."
 S.PROBLEMS.skillAuxiliaryBarUnavailable="An affected special bar is unavailable."
 S.PROBLEMS.buildCapabilityUnavailable="A required build capability is unavailable."
 S.PROBLEMS.attributeAdapterRefused="The attribute target cannot be prepared."
end

do
 local S=KanaWardrobe.Strings
 S.BUILD_OVERRIDE_unknownOverride="This ultimate override requires a supported rule before changing the slot."
 S.BUILD_OVERRIDE_targetCryptcanon="Cryptcanon overrides this ultimate in the target equipment. Change the preset target."
 S.BUILD_OVERRIDE_removeCryptcanonManually="Remove the currently equipped Cryptcanon manually before changing the ultimate."
end

do
 local S=KanaWardrobe.Strings
 S.SAVE_AND_APPLY="Save and apply"
 S.ATTRIBUTES_INCLUDE="Save attributes"
 S.CLEAR_skills="Remove skills"
 S.CLEAR_bars="Remove action bars"
 S.CLEAR_equipment="Remove equipment"
 S.CLEAR_attributes="Remove attributes"
 S.CLEAR_GROUP_HELP="Uncheck this part of the preset. Takes effect when you save; your character is unchanged."
 S.SAVE_AND_APPLY_HELP="Save selected entries, then apply every change in this page's current experiment, including unselected entries."
 S.COMPONENT_SAVE_HELP="Save the selected part and discard this page's experiment. Skills and attributes are not purchased."
 S.COMPONENT_CANCEL_HELP="Discard this page's experiment without saving or purchasing skills and attributes."
 S.RECOVERY_ACTIONS="Recovery actions"
 S.RECOVER_confirmActualTarget="Confirm actual target"
 S.RECOVER_acceptCurrent="Accept current build"
 S.RECOVER_remaining="Apply remaining parts"
 S.RECOVER_restore="Restore original equipment"
 S.RECOVER_relinquishUnsent="Release unsent request; keep native draft"
 S.RECOVERY_ACCEPT_HELP="Accept the current actual build as the endpoint and end this operation? A missing server result remains unknown. This does not resend the old request."
 S.QUICK_SAVE_HELP="Save current actual equipment, skills, both normal action bars, attributes and appearance to the shared quick slot. Pending edits are excluded."
 S.QUICK_LOAD_HELP="Apply every included part of the shared quick snapshot."
 local problems={
  invalidEditorPage="Open equipment, skills or character attributes to edit this part.",
  editorDomainMismatch="This selection belongs to another page.",invalidSelection="The selection is invalid.",
  invalidComponent="The preset part is invalid.",invalidComponentPatch="The saved part could not be updated.",
  nativeDraftUnavailable="This page's native editor is unavailable.",
  buildRunnerError="The build operation stopped. Check the current actual build before recovery.",
  buildRequestTimeout="The server result was not received. Check the actual build and choose a recovery action.",
  buildSubmissionUnresolved="A native request remains unresolved. Reconcile it before applying another build.",
  nativeRespecRefused="The native respec request was refused.",
  attributeCastPending="Wait for the current attribute respec cast to end.",
  foreignAttributeDraft="Finish or discard the existing native attribute edits first.",
  foreignSkillDraft="Finish or discard the existing native skill edits first.",
  buildStateChanged="The actual build or available points changed. Review the operation again.",
  skillSubmissionUncertain="The skill request outcome is unknown. Check actual skills before choosing recovery.",
  attributeSubmissionUncertain="The attribute request outcome is unknown. Check actual attributes before choosing recovery.",
  skillCastPending="Wait for the current skill respec cast to end.",skillDraftActive="Finish the current skill experiment first.",
  skillDraftCleanupFailed="The skill experiment could not be safely closed. Review native pending edits.",
  skillDraftFailed="The native skill experiment could not be prepared.",skillEntryNotReady="The native skill respec page is not ready.",
  skillEntryTimeout="ESO did not open skill redistribution. No skill changes were sent. You can select a preset again.",
  skillSubmissionActive="The previous native skill request is still active.",skillSubmissionFailed="The native skill request failed.",
  skillSubmissionTokenMismatch="The native request changed. Review the current recovery state.",
 }
 for code,message in pairs(problems)do S.PROBLEMS[code]=message end
end

KanaWardrobe.Strings.REPAIR_REMOVE="Remove reference"
KanaWardrobe.Strings.REPAIR_REPLACE="Replace with current draft"

KanaWardrobe.Strings.PROGRESS_SHEATHING="Weapons…"
KanaWardrobe.Strings.PROGRESS_EQUIPMENT="Equipment"
KanaWardrobe.Strings.PROGRESS_SKILLS="Skills"
KanaWardrobe.Strings.PROGRESS_ATTRIBUTES="Attributes"
KanaWardrobe.Strings.PROGRESS_COOLDOWN="cooldown"
KanaWardrobe.Strings.BUILD_RETRY_PRESET="You can select a preset again; already applied changes are kept."
KanaWardrobe.Strings.SKILL_BLOCK_allocation="ESO reports pending skill purchases or morph changes."
KanaWardrobe.Strings.SKILL_BLOCK_bars="ESO reports differences between the actual and edited skill bars."
KanaWardrobe.Strings.SKILL_BLOCK_lines="ESO reports pending changes to skill lines."
KanaWardrobe.Strings.SKILL_BLOCK_mode="The native skill editor is still in redistribution mode."
KanaWardrobe.Strings.SKILL_BLOCK_dirty="The native skill manager has an unsent-change flag."
KanaWardrobe.Strings.SKILL_BLOCK_unknown="The skill editor check blocked this action, but the pending change could not be identified."
KanaWardrobe.Strings.SKILL_BLOCK_REPORT_SAVED="Diagnostic report saved: /kw probe blocked."
KanaWardrobe.Strings.SKILL_BLOCK_NO_REPORT="No skill-block diagnostic report has been recorded."
KanaWardrobe.Strings.EQUIPMENT_TIMEOUT_SLOTS="Equipment change did not finish: %s. Diagnostics saved."

-- Visible sequential operations. Diagnostics remain available after /reloadui.
do
 local S=KanaWardrobe.Strings
 local labels={TITLE='Preset operation',PAUSE='Pause',CONTINUE='Continue',RESTART='Start over',REPORT='Copy report',CONFIRM='Confirm',
  HINT='Close hides this window. Pause waits for the current action to finish.',FAILED_HINT='Fix the cause, then continue this step or calculate a new plan.',PAUSED_HINT='No actions will run until you press Continue.',
  running='In progress',pausing='Pausing after this action',paused='Paused',failed='Stopped at an error',
  diff='Calculate changes and check requirements',equip='Equip',equipBatch='Change equipment',unequip='Remove',attributes='Set attributes',skills='Set talents',bar='Set action bar',front='Front',back='Back',
  verify='Verify actual result',save='Save preset',mountDraft='Prepare local draft',closeDraft='Close local draft',openEditor='Open editor',finishEditor='Finish editing',
  EMPTY='Empty',ITEM_ID='Item ID',MORE='… and %d more changes (full report available)',ATTEMPT='Attempt %d',REOPEN='Operation steps',
  SKILL='Skill',SKILL_MORPH='Change morph: “%s” → “%s”.',SKILL_MORPH_UNKNOWN='Change the morph of “%s”.',
  SKILL_LEARN='Learn “%s”.',SKILL_REMOVE='Unlearn “%s”.',SKILL_RANK='%s: rank %d → %d.',BAR_SKILL='Slot %d: “%s”.',BAR_EMPTY='Clear slot %d.',
  MORPH_FRONT='Front bar: morph “%s” will change to “%s”.',MORPH_BACK='Back bar: morph “%s” will change to “%s”.',
  MORPH_UNKNOWN_FRONT='Front bar: the morph of “%s” will change.',MORPH_UNKNOWN_BACK='Back bar: the morph of “%s” will change.',
  REMOVE_FRONT='“%s” will be removed from the front bar because it will be unlearned.',REMOVE_BACK='“%s” will be removed from the back bar because it will be unlearned.'}
 for key,value in pairs(labels)do S['OP_'..key]=value end
 local problems={operationBusy='An action is still running. Pause waits for its result.',operationUnconfirmed='The request was sent, but its result has not been confirmed. This does not mean nothing changed.',
  operationDependenciesChanged='The item, slot or native request changed after planning. Start over to recalculate from the current state.',operationMismatch='The actual result differs from the planned result.',
  operationError='An internal addon error stopped this step.',operationConsent='The plan also changes unselected slots. Confirm these additional changes.',invalidOperation='The saved operation cannot be resumed. Its report is preserved; you can select another preset.'}
 for key,value in pairs(problems)do S.PROBLEMS[key]=value end
end

for k,v in pairs({apply='Apply',edit='Edit',new='New preset',save='Save',saveApply='Save and apply',cancel='Finish editing'})do KanaWardrobe.Strings['OP_ACTION_'..k]=v end

KanaWardrobe.Strings.PROBLEMS.bagFull="No free backpack slot. Free one slot and press Continue."
KanaWardrobe.Strings.PROBLEM_UNRECOGNIZED="The addon did not recognize the failure (%s). The step has stopped."
KanaWardrobe.Strings.REPORT_PREVIOUS="Previous"
KanaWardrobe.Strings.REPORT_NEXT="Next"

for key,value in pairs({VALUE='%s: expected %s; now %s.',RANK='“%s”: expected rank %d; now %d.',
 MORPH='Expected morph “%s”; now “%s”.',REMOVE='“%s” should be unlearned, but is still learned.',LEARN='“%s” has not been learned.',
 BAR='%s, slot %d: expected “%s”; now “%s”.',ITEM_COPY='%s: another copy of “%s” is equipped.',
 MISSING='%s: could not read the current state.',UNREADABLE='unavailable',EMPTY='empty',SKILL='Skill',ITEM='item',BUILD='Build',
 health='Health',magicka='Magicka',stamina='Stamina',front='Front bar',back='Back bar',werewolf='Werewolf bar',SPECIAL_BAR='Special bar',
 abilities='Skills and bars',skills='Talents',bars='Action bars',equipment='Equipment',attributes='Attributes',
 RETRY='Start over to apply the remaining changes.'})do KanaWardrobe.Strings['MISMATCH_'..key]=value end

KanaWardrobe.Strings.OP_werewolf="Werewolf"
KanaWardrobe.Strings.OP_MORPH_WEREWOLF="Werewolf bar: morph “%s” will change to “%s”."
KanaWardrobe.Strings.OP_MORPH_UNKNOWN_WEREWOLF="Werewolf bar: the morph of “%s” will change."
KanaWardrobe.Strings.OP_REMOVE_WEREWOLF="“%s” will be removed from the werewolf bar because it will be unlearned."

KanaWardrobe.Strings.PROBLEMS.skillWerewolfOnly="Only werewolf skills can be assigned to the werewolf bar."
KanaWardrobe.Strings.OP_MOVE_FRONT="“%s” will move to slot %d on the front bar."
KanaWardrobe.Strings.OP_MOVE_BACK="“%s” will move to slot %d on the back bar."
KanaWardrobe.Strings.OP_MOVE_WEREWOLF="“%s” will move to slot %d on the werewolf bar."

KanaWardrobe.Strings.APPEARANCE='Appearance'
KanaWardrobe.Strings.OP_APPEARANCE_COOLDOWN='Appearance cooldown: %d s remaining.'
KanaWardrobe.Strings.OP_APPEARANCE_RETRY='Appearance is on cooldown. Automatic retry in %d s.'
KanaWardrobe.Strings.OP_APPEARANCE_COOLDOWN_UNKNOWN='Waiting for the appearance cooldown.'
KanaWardrobe.Strings.PROBLEMS.appearanceCooldownTimeout='The appearance cooldown has not finished. Try this step again.'
KanaWardrobe.Strings.EMPTY_LIST='Create a preset on this page.'
KanaWardrobe.Strings.OUTCOME_quickSaved='Current build saved to the quick slot.'
KanaWardrobe.Strings.CLEAR_appearance='Remove appearance'
KanaWardrobe.Strings.OP_appearance='Set appearance'
KanaWardrobe.Strings.MISMATCH_appearance='Appearance'
KanaWardrobe.Strings.APPEARANCE_MISMATCH='%s: expected “%s”; now “%s”. Try this step again.'
KanaWardrobe.Strings.APPEARANCE_SAVE_HELP='Save selected categories and restore your previous appearance.'
KanaWardrobe.Strings.APPEARANCE_CANCEL_HELP='Discard changes to the preset and restore your previous appearance.'
KanaWardrobe.Strings.APPEARANCE_CLOSE_HELP='Save or discard the preset changes and restore your previous appearance, or continue editing.'
KanaWardrobe.Strings.OUTCOME_appearanceSaved='Preset saved. Previous appearance restored.'
KanaWardrobe.Strings.OUTCOME_appearanceCancelled='Editing cancelled. Previous appearance restored.'
for key,value in pairs({COSTUME={'Costume','No costume'},HAT={'Hat','No hat'},HAIR={'Hairstyle','No hairstyle override'},
 FACIAL_HAIR_HORNS={'Facial hair / horns','No facial hair / horns override'},FACIAL_ACCESSORY={'Facial accessory','No facial accessory'},
 PIERCING_JEWELRY={'Adornments','No adornments'},HEAD_MARKING={'Head marking','No head marking'},BODY_MARKING={'Body marking','No body marking'},
 SKIN={'Skin','No skin'},POLYMORPH={'Polymorph','No polymorph'},PERSONALITY={'Personality','No personality'}})do
 KanaWardrobe.Strings['APPEARANCE_'..key]=value[1];KanaWardrobe.Strings['APPEARANCE_NONE_'..key]=value[2]
end
for key,value in pairs({appearanceUnavailable='Could not read your current appearance.',appearanceCategoryUnavailable='This appearance category is unavailable.',
 appearanceWrongCategory='The saved collectible does not belong to this category.',appearanceLocked='The saved collectible is not unlocked.',
 appearanceBlocked='ESO cannot apply this collectible right now.',appearanceUnconfirmed='ESO has not applied this appearance change.'})do KanaWardrobe.Strings.PROBLEMS[key]=value end

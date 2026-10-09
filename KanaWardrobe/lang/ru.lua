if GetCVar and GetCVar("language.2")=="ru" then
    local S=KanaWardrobe.Strings
    S.PROBE_REPORT_TITLE="Отчёт проверки билда"
    S.NEW_PRESET="Новый пресет"
    S.ADDON_NAME="KanaWardrobe"
    S.INVALID_NAME="Введите имя без разметки длиной от 1 до 48 символов."
    S.DUPLICATE_NAME="Пресет с таким именем уже существует."
    S.DUPLICATE="Дублировать"
    S.COPY="копия"
    S.BINDING_CONFIRMATION_REQUIRED="Сначала наденьте вещь вручную и подтвердите её привязку в игре."
end
if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 local labels={PRESETS="Пресеты",APPLY="Применить",SAVE="Сохранить",CANCEL="Отмена",CONTINUE="Продолжить",RENAME="Переименовать",EDIT="Редактировать",DELETE="Удалить",CLOSE="Закрыть",ALL="Все",NONE="Ни одного",WORN="Надето",MISSING="Нет: %d",EMPTY_LIST="Сохраните часть экипировки в пресет.",EDIT_HELP="Отметьте сохраняемые слоты. Отмеченная пустота снимает вещь при применении.",RETURN_NOTE="Сохранение и отмена вернут прежнюю экипировку.",SAVED_RETURN="Пресет сохранён. Возвращаем экипировку…",PAUSED="Приостановлено. Продолжите, когда будете готовы.",RESUME="Продолжить",RECOVERY="Возврат экипировки",RESTORE="Вернуть экипировку",RESTORE_AVAILABLE="Вернуть доступное",KEEP_CURRENT="Оставить надетое",KEEP_WARNING="Исходная экипировка возвращена не полностью. Завершить сессию и оставить надетые сейчас вещи?",RECOVERY_HELP="Предыдущая операция не завершена. Верните прежнюю экипировку или явно выберите сохранение текущей.",CLOSE_EDITOR="Завершить редактирование?",CLOSE_HELP="Сохраните или отмените изменения пресета с возвратом экипировки либо продолжите редактирование.",DELETE_TITLE="Удалить пресет?",DELETE_HELP="Удалить «%s»? Вещи останутся заблокированными. При необходимости снимите блокировки вручную.",EXTRAS_TITLE="Применить пресет «%s»?",EXTRAS_HELP="Дополнительно потребуется:",EXTRA_REMOVE="%s: %s → в сумку — %s",EXTRA_MOVE="%s: %s → %s (исходный слот освободится) — %s",REASON_twoHanded="место для двуручного оружия",REASON_mythic="можно надеть только один мифик",REASON_sourceMove="перенос именно этой вещи в заданный слот",REASON_uniqueEquipped="можно надеть только один такой уникальный предмет",MISSING_HELP="Нет в сумке и на персонаже:",RESTORE_MISSING_HELP="Эти исходные вещи не будут возвращены. Сессия восстановления останется открытой:",USE_WORN="Использовать надетое",SAVE_EMPTY="Сохранить пустым",OMIT_SLOT="Не сохранять слот",RESOLVE="Разобрать пропавшие вещи",SELECTED_SLOT="Сохранить этот слот",HIDE_ITEMS="Скрыть вещи пресетов: %d",HIDE_BYPASS="Скрытие вещей пресетов отключено до завершения редактора.",PRESET_SETS="Сеты пресета",PERFECTED_PARTS="Совершенные части",SET_ITEMS_MISSING="Часть вещей пресета отсутствует в сумке и на персонаже.",SET_DATA_UNAVAILABLE="Сведения о сетах этого пресета недоступны.",NO_PRESET_SETS="В этом пресете нет сетовых вещей.",TOOLTIP_PRESETS="Пресеты: %s",TOOLTIP_OTHER_CHARACTER="%s (%s)",UNKNOWN_PROBLEM="Не удалось завершить операцию. Проверьте экипировку и повторите действие.",EMPTY_SELECTION="Отметьте хотя бы один слот.",BUSY="Сначала завершите текущую операцию.",STATE_applying="Надеваем…",STATE_preparingEdit="Готовим редактор…",STATE_restoring="Возвращаем экипировку…",STATE_confirming="Ожидаем подтверждения…",STATE_recovery="Необходимо вернуть экипировку.",NAME="Имя пресета",MISSING_EDIT="Редактировать доступные вещи?",MISSING_EDIT_HELP="Пропавшие вещи останутся отмечены, пока вы явно не замените, не очистите или не исключите их слоты."}
 for k,v in pairs(labels)do S[k]=v end
 S.SLOT_NAMES={"Голова","Плечи","Тело","Руки","Пояс","Ноги","Ступни","Ожерелье","Кольцо 1","Кольцо 2","Правая рука · I","Левая рука · I","Правая рука · II","Левая рука · II"}
 local P={invalidName=S.INVALID_NAME,nameTooLong=S.INVALID_NAME,duplicateName=S.DUPLICATE_NAME,bindingConfirmationRequired=S.BINDING_CONFIRMATION_REQUIRED,itemMissing="Нужного экземпляра нет в сумке и на персонаже.",cannotLock="Эту вещь нельзя заблокировать.",lockFailed="Блокировка вещи не подтверждена.",lockConflict="Вещь пресета разблокирована. Заблокируйте её снова.",sourceChanged="Вещь переместилась или изменилась. Повторите действие.",itemProtected="Этот экземпляр сохранён в пресете и должен оставаться заблокированным.",lockPending="Ожидаем подтверждения блокировок.",inCombat="Дождитесь окончания боя и повторите действие.",dead="Воскресните перед сменой экипировки.",blocking="Отпустите блок и повторите действие.",busy=S.BUSY,invalidPreset="Данные пресета повреждены.",presetMissing="Этот пресет больше не существует.",revisionConflict="Пресет изменился. Откройте его заново.",invalidSlot="Этот слот экипировки не поддерживается.",duplicateUid="Одна вещь назначена нескольким слотам.",invalidItem="Сведения о сохранённой вещи недоступны.",incompatibleSlot="Вещь не подходит выбранному слоту.",insufficientSpace="В сумке недостаточно свободных мест.",notEquipable="Сейчас эту вещь надеть нельзя.",slotUnavailable="Этот слот экипировки недоступен.",mythicConflict="Выбрано несколько мификов.",uniqueEquippedConflict="Выбрано несколько одинаковых уникальных вещей.",weaponConflict="Выбранное оружие нельзя надеть вместе.",unplannable="Нельзя безопасно выполнить смену экипировки.",externalChange="Экипировка изменилась во время операции. Проверьте её перед продолжением.",requestError="Игра не приняла запрос смены экипировки.",requestRejected="Запрос смены экипировки отклонён.",requestTimeout="Истекло время ожидания. Перед повтором нужно проверить результат запроса.",sheathTimeout="Не удалось подтвердить убирание оружия. Повторите действие.",stalePlan="Экипировка изменилась. Повторите действие.",targetMismatch="Фактическая экипировка отличается от запрошенной.",stopped="Операция остановлена.",sceneHidden="Инвентарь закрыт. Операция приостановлена.",missingUnresolved="Разберите все пропавшие вещи перед сохранением.",noSelection=S.EMPTY_SELECTION,emptySelection=S.EMPTY_SELECTION,setDataUnavailable=S.SET_DATA_UNAVAILABLE,notEditing="Сначала откройте редактор.",paused=S.PAUSED,invalidNameType=S.INVALID_NAME}
 for _,key in ipairs({"invalidIntent","invalidMode","invalidPlan","invalidSnapshot","invalidState","invalidStep"})do P[key]="Некорректные данные экипировки. Откройте инвентарь заново." end
 S.PROBLEMS=P
end
if GetCVar and GetCVar("language.2")=="ru" then KanaWardrobe.Strings.PROBLEMS.progressObserverError="Операция прервана при проверке её хода. Проверьте экипировку перед продолжением." end
if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 local P={noSlotsSelected=S.EMPTY_SELECTION,unresolvedMissing="Разберите все пропавшие вещи перед сохранением.",invalidMissingChoice="Выберите, что сделать с пропавшей вещью.",replacementRequired="Сначала наденьте замену в этот слот.",emptyRequired="Сначала снимите надетую вещь из этого слота.",confirmationChanged="Необходимые изменения поменялись. Проверьте новое подтверждение.",recoveryRequired="Сначала завершите возврат экипировки.",pendingRequest="Предыдущий запрос ещё не подтверждён. Проверьте его результат перед повтором.",originalItemsMissing="Часть исходных вещей недоступна. Проверьте список перед возвратом только доступных вещей.",partialRestore="Доступные вещи возвращены. Часть исходных вещей отсутствует; восстановление ещё не завершено.",invalidJournal="Запись восстановления повреждена. Проверьте экипировку и явно выберите, оставлять ли её.",invalidRecoveryAction="Выберите действие восстановления."}
 for k,v in pairs(P)do S.PROBLEMS[k]=v end
end
if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 S.OUTCOME_applied="Пресет применён."
 S.OUTCOME_saved="Пресет сохранён. Прежняя экипировка возвращена."
 S.OUTCOME_cancelled="Редактирование отменено. Прежняя экипировка возвращена."
 S.OUTCOME_keptCurrent="Сессия завершена. Оставлена текущая экипировка."
 S.OUTCOME_interruptedApply="Предыдущее применение было прервано. Можно снова выбрать пресет."
end
if GetCVar and GetCVar("language.2")=="ru" then KanaWardrobe.Strings.PROBLEMS.recoveryChanged="Состояние билда изменилось после проверки. Заново откройте действия восстановления и выберите нужное действие." end
if GetCVar and GetCVar("language.2")=="ru" then KanaWardrobe.Strings.PROBLEMS.commitObserverError="Не удалось завершить сохранение. Проверьте статус пресета и выберите способ восстановления экипировки." end
if GetCVar and GetCVar("language.2")=="ru" then
 KanaWardrobe.Strings.STATE_idle="Готово к работе."
 KanaWardrobe.Strings.STATE_editing="Редактирование пресета."
end

if GetCVar and GetCVar("language.2")=="ru" then
KanaWardrobe.Strings.PRESET_SUMMARY="Сводка пресета"
KanaWardrobe.Strings.SUMMARY_ARMOR="Броня"
KanaWardrobe.Strings.SUMMARY_ENCHANTS="Зачарования"
KanaWardrobe.Strings.SUMMARY_TRAITS="Трейты"
end

if GetCVar and GetCVar("language.2")=="ru" then
KanaWardrobe.Strings.SUMMARY_FRONT="Основная"
KanaWardrobe.Strings.SUMMARY_BACK="Запасная"
KanaWardrobe.Strings.SUMMARY_ITEMS="предметов"
end

if GetCVar and GetCVar("language.2")=="ru" then
KanaWardrobe.Strings.SUMMARY_COMPOSITION="Состав"
KanaWardrobe.Strings.SUMMARY_BAR_LEGEND="I · Основная   |   II · Запасная"
end

if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 S.QUICK_PRESET="Быстрый снимок"
 S.QUICK_SAVE="Сохранить"
 S.QUICK_LOAD="Загрузить"
 S.QUICK_SAVE_HELP="Сохранить текущую экипировку в быструю ячейку, заменив предыдущую запись. Пустые слоты тоже сохраняются."
 S.QUICK_LOAD_HELP="Надеть экипировку из быстрой ячейки. Запись останется до следующего быстрого сохранения."
 S.QUICK_EMPTY="Сначала сохраните экипировку в быструю ячейку."
 S.OUTCOME_quickSaved="Экипировка сохранена в быструю ячейку."
end
if GetCVar and GetCVar("language.2")=="ru" then KanaWardrobe.Strings.CAPACITY_HIDDEN="(скрыто: %d)" end

if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 S.BUILD_EMPTY="пусто"
 S.BUILD_ABILITY_EXTRA="%s — панель %s, слот %d: %s → %s"
 S.PROBLEMS.invalidBuildSnapshot="Нет фактического билда или бюджета."
 S.PROBLEMS.attributesUnavailable="Характеристики недоступны."
 S.PROBLEMS.skillsUnavailable="Навыки недоступны."
 S.PROBLEMS.insufficientAttributePoints="Недостаточно очков характеристик."
 S.PROBLEMS.insufficientSkillPoints="Недостаточно очков навыков."
 S.PROBLEMS.insufficientMasteryPoints="Недостаточно очков классового мастерства."
 S.PROBLEMS.equipmentOverride="Ультимативная способность заменена экипировкой. Снимите Криптканон вручную перед изменением."
 S.PROBLEMS.confirmedBuildMismatch="Фактический билд не совпадает с подтверждённым этапом."
 S.PROBLEMS.buildDependenciesChanged="Зависимости билда изменились; подтвердите заново."
end

if GetCVar and GetCVar("language.2")=="ru" then KanaWardrobe.Strings.BUILD_DEFICIT="Нужно %d, доступно %d, не хватает %d." end

if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 S.PROBLEMS.skillUnavailable="Навык или развитие недоступны."
 S.PROBLEMS.skillImmutable="Этот навык нельзя изменить."
 S.PROBLEMS.skillMorphLocked="Запрошенный морф закрыт."
 S.PROBLEMS.skillRankLocked="Запрошенный ранг закрыт."
 S.PROBLEMS.skillMorphMismatch="Морф панели не совпадает с итоговым морфом навыка."
 S.PROBLEMS.skillBarType="Способность не подходит для этого слота панели."
 S.PROBLEMS.duplicateBarSkill="Один навык назначен дважды на одной панели."
 S.PROBLEMS.skillBarLocked="Затронутый слот панели закрыт."
 S.PROBLEMS.skillBarOverride="Затронутый слот панели заменён или неизменяем."
 S.PROBLEMS.skillAuxiliaryBarUnavailable="Затронутая специальная панель недоступна."
 S.PROBLEMS.buildCapabilityUnavailable="Необходимая возможность билда недоступна."
 S.PROBLEMS.attributeAdapterRefused="Нельзя подготовить целевые характеристики."
end

if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 S.BUILD_OVERRIDE_unknownOverride="Для изменения этого слота нужен поддерживаемый механизм замены ультимативной способности."
 S.BUILD_OVERRIDE_targetCryptcanon="Криптканон заменяет эту ультимативную способность в целевой экипировке. Измените цель пресета."
 S.BUILD_OVERRIDE_removeCryptcanonManually="Снимите надетый Криптканон вручную перед изменением ультимативной способности."
end

if GetCVar and GetCVar("language.2")=="ru" then
 local S=KanaWardrobe.Strings
 S.SAVE_AND_APPLY="Сохранить и применить"
 S.ATTRIBUTES_INCLUDE="Сохранять характеристики"
 S.CLEAR_skills="Удалить навыки"
 S.CLEAR_bars="Удалить панель"
 S.CLEAR_equipment="Удалить экипировку"
 S.CLEAR_attributes="Удалить атрибуты"
 S.CLEAR_GROUP_HELP="Снять галочки с этой части пресета. Изменение сохранится по кнопке «Сохранить»; билд персонажа не меняется."
 S.SAVE_AND_APPLY_HELP="Сохранить отмеченное, затем применить все изменения текущего эксперимента на этой странице, включая неотмеченные."
 S.COMPONENT_SAVE_HELP="Сохранить выбранную часть и отменить эксперимент этой страницы. Навыки и характеристики не покупаются."
 S.COMPONENT_CANCEL_HELP="Отменить эксперимент этой страницы без сохранения и покупки навыков или характеристик."
 S.RECOVERY_ACTIONS="Действия восстановления"
 S.RECOVER_confirmActualTarget="Подтвердить фактическую цель"
 S.RECOVER_acceptCurrent="Принять текущий билд"
 S.RECOVER_remaining="Применить оставшиеся части"
 S.RECOVER_restore="Вернуть исходную экипировку"
 S.RECOVER_relinquishUnsent="Освободить неотправленный запрос; оставить штатные правки"
 S.RECOVERY_ACCEPT_HELP="Принять текущий фактический билд и завершить операцию? Если ответ сервера потерян, исход запроса останется неизвестным. Старый запрос повторно не отправляется."
 S.QUICK_SAVE_HELP="Сохранить фактическую экипировку, навыки, обе обычные панели, характеристики и внешний вид в общую быструю ячейку. Незавершённые правки не включаются."
 S.QUICK_LOAD_HELP="Применить все включённые части общего быстрого снимка."
 local problems={
  invalidEditorPage="Для редактирования этой части откройте экипировку, навыки или характеристики персонажа.",
  editorDomainMismatch="Эта галочка относится к другой странице.",invalidSelection="Недопустимое состояние выбора.",
  invalidComponent="Недопустимая часть пресета.",invalidComponentPatch="Не удалось обновить сохраняемую часть.",
  nativeDraftUnavailable="Штатный редактор этой страницы недоступен.",
  buildRunnerError="Операция билда остановлена. Проверьте фактический билд перед восстановлением.",
  buildRequestTimeout="Ответ сервера не получен. Проверьте фактический билд и выберите действие восстановления.",
  buildSubmissionUnresolved="Исход штатного запроса ещё не выяснен. Завершите восстановление перед следующим применением.",
  nativeRespecRefused="Штатный запрос перераспределения отклонён.",
  attributeCastPending="Дождитесь завершения перераспределения характеристик.",
  foreignAttributeDraft="Сначала завершите или отмените существующие штатные правки характеристик.",
  foreignSkillDraft="Сначала завершите или отмените существующие штатные правки навыков.",
  buildStateChanged="Фактический билд или доступные очки изменились. Проверьте действие заново.",
  skillSubmissionUncertain="Исход запроса навыков неизвестен. Проверьте фактические навыки перед восстановлением.",
  attributeSubmissionUncertain="Исход запроса характеристик неизвестен. Проверьте фактические характеристики перед восстановлением.",
  skillCastPending="Дождитесь завершения перераспределения навыков.",skillDraftActive="Сначала завершите текущий эксперимент навыков.",
  skillDraftCleanupFailed="Не удалось безопасно закрыть эксперимент навыков. Проверьте штатные незавершённые правки.",
  skillDraftFailed="Не удалось подготовить штатный эксперимент навыков.",skillEntryNotReady="Штатная страница перераспределения навыков ещё не готова.",
  skillEntryTimeout="ESO не открыл перераспределение навыков. Изменения навыков не отправлены. Можно снова выбрать пресет.",
  skillSubmissionActive="Предыдущий штатный запрос навыков ещё выполняется.",skillSubmissionFailed="Штатный запрос навыков не выполнен.",
  skillSubmissionTokenMismatch="Штатный запрос изменился. Проверьте текущее состояние восстановления.",
 }
 for code,message in pairs(problems)do S.PROBLEMS[code]=message end
end

if GetCVar and GetCVar("language.2")=="ru" then
 KanaWardrobe.Strings.REPAIR_REMOVE="Удалить ссылку"
 KanaWardrobe.Strings.REPAIR_REPLACE="Заменить текущим выбором"
end

if GetCVar and GetCVar('language.2')=='ru' then KanaWardrobe.Strings.PROGRESS_SHEATHING="Оружие…" end
if GetCVar and GetCVar('language.2')=='ru' then
 KanaWardrobe.Strings.PROGRESS_EQUIPMENT="Экипировка"
 KanaWardrobe.Strings.PROGRESS_SKILLS="Навыки"
 KanaWardrobe.Strings.PROGRESS_ATTRIBUTES="Атрибуты"
 KanaWardrobe.Strings.PROGRESS_COOLDOWN="перезарядка"
 KanaWardrobe.Strings.BUILD_RETRY_PRESET="Можно снова выбрать пресет; уже применённые изменения сохранены."
 KanaWardrobe.Strings.SKILL_BLOCK_allocation="ESO сообщает о неприменённых изменениях изучения или морфов навыков."
 KanaWardrobe.Strings.SKILL_BLOCK_bars="ESO сообщает о расхождении фактической и редактируемой панелей навыков."
 KanaWardrobe.Strings.SKILL_BLOCK_lines="ESO сообщает о неприменённых изменениях веток навыков."
 KanaWardrobe.Strings.SKILL_BLOCK_mode="Штатный редактор навыков остался в режиме перераспределения."
 KanaWardrobe.Strings.SKILL_BLOCK_dirty="У штатного редактора навыков установлен флаг неотправленного изменения."
 KanaWardrobe.Strings.SKILL_BLOCK_unknown="Проверка редактора навыков заблокировала действие, но конкретную незавершённую правку определить не удалось."
 KanaWardrobe.Strings.SKILL_BLOCK_REPORT_SAVED="Диагностика сохранена: /kw probe blocked."
 KanaWardrobe.Strings.SKILL_BLOCK_NO_REPORT="Отчёта о блокировке навыков пока нет."
 KanaWardrobe.Strings.EQUIPMENT_TIMEOUT_SLOTS="Не завершена смена экипировки: %s. Диагностика сохранена."
end

if GetCVar and GetCVar('language.2')=='ru'then
 local S=KanaWardrobe.Strings
 local labels={TITLE='Применение пресета',PAUSE='Пауза',CONTINUE='Продолжить',RESTART='Начать сначала',REPORT='Скопировать отчёт',CONFIRM='Подтвердить',
  HINT='Крестик скрывает окно. Пауза дожидается результата текущего действия.',FAILED_HINT='Исправьте причину и продолжите шаг либо постройте план заново.',PAUSED_HINT='Действия начнутся только после нажатия «Продолжить».',
  running='Выполняется',pausing='Остановка после текущего действия',paused='На паузе',failed='Остановлено на ошибке',
  diff='Вычислить изменения и проверить условия',equip='Надеть',equipBatch='Сменить экипировку',unequip='Снять',attributes='Выставить атрибуты',skills='Выставить таланты',bar='Выставить панель',front='Основная',back='Запасная',
  verify='Проверить фактический результат',save='Сохранить пресет',mountDraft='Подготовить черновик',closeDraft='Закрыть черновик',openEditor='Открыть редактор',finishEditor='Завершить редактирование',
  EMPTY='Пусто',ITEM_ID='ID вещи',MORE='… и ещё %d изменений (подробности в отчёте)',ATTEMPT='Попытка %d',REOPEN='Шаги операции',
  SKILL='Навык',SKILL_MORPH='Сменить морф: «%s» → «%s».',SKILL_MORPH_UNKNOWN='Сменить морф навыка «%s».',
  SKILL_LEARN='Изучить «%s».',SKILL_REMOVE='Забыть «%s».',SKILL_RANK='%s: ранг %d → %d.',BAR_SKILL='Ячейка %d: «%s».',BAR_EMPTY='Очистить ячейку %d.',
  MORPH_FRONT='На первой панели морф «%s» сменится на «%s».',MORPH_BACK='На второй панели морф «%s» сменится на «%s».',
  MORPH_UNKNOWN_FRONT='На первой панели изменится морф навыка «%s».',MORPH_UNKNOWN_BACK='На второй панели изменится морф навыка «%s».',
  REMOVE_FRONT='«%s» будет убран с первой панели, поскольку навык будет сброшен.',REMOVE_BACK='«%s» будет убран со второй панели, поскольку навык будет сброшен.'}
 for key,value in pairs(labels)do S['OP_'..key]=value end
 local problems={operationBusy='Действие ещё выполняется. Пауза дождётся его результата.',operationUnconfirmed='Запрос отправлен, но результат пока не подтверждён. Это не означает, что ничего не изменилось.',
  operationDependenciesChanged='После расчёта изменился предмет, слот или штатный запрос. Нажмите «Начать сначала», чтобы пересчитать план по текущему состоянию.',operationMismatch='Фактический результат отличается от запланированного.',
  operationError='Внутренняя ошибка аддона остановила этот шаг.',operationConsent='План затрагивает также неотмеченные слоты. Подтвердите эти дополнительные изменения.',invalidOperation='Сохранённую операцию нельзя продолжить. Отчёт сохранён; можно выбрать другой пресет.'}
 for key,value in pairs(problems)do S.PROBLEMS[key]=value end
end

if GetCVar and GetCVar('language.2')=='ru'then
 for k,v in pairs({apply='Применить',edit='Редактировать',new='Новый пресет',save='Сохранить',saveApply='Сохранить и применить',cancel='Завершить редактирование'})do KanaWardrobe.Strings['OP_ACTION_'..k]=v end
end

if GetCVar and GetCVar('language.2')=='ru'then
 local S=KanaWardrobe.Strings
 S.PROBLEMS.bagFull='В сумке нет свободного места. Освободите одну ячейку и нажмите «Продолжить».'
 S.PROBLEM_UNRECOGNIZED='Аддон не распознал причину отказа (%s). Шаг остановлен.'
 S.REPORT_PREVIOUS='Назад'
 S.REPORT_NEXT='Далее'
end

if GetCVar and GetCVar('language.2')=='ru'then
 for key,value in pairs({VALUE='%s: нужно %s, сейчас %s.',RANK='«%s»: нужен ранг %d, сейчас %d.',
  MORPH='Нужен морф «%s», сейчас «%s».',REMOVE='«%s» должен быть сброшен, но всё ещё изучен.',LEARN='«%s» не изучен.',
  BAR='%s, ячейка %d: нужно «%s», сейчас «%s».',ITEM_COPY='%s: надет другой экземпляр «%s».',
  MISSING='%s: не удалось прочитать текущее состояние.',UNREADABLE='не удалось прочитать',EMPTY='пусто',SKILL='Навык',ITEM='предмет',BUILD='Билд',
  health='Здоровье',magicka='Магия',stamina='Запас сил',front='Первая панель',back='Вторая панель',werewolf='Панель вервольфа',SPECIAL_BAR='Дополнительная панель',
  abilities='Навыки и панели',skills='Таланты',bars='Панели навыков',equipment='Экипировка',attributes='Атрибуты',
  RETRY='Нажмите «Начать сначала», чтобы применить оставшиеся изменения.'})do KanaWardrobe.Strings['MISMATCH_'..key]=value end
end

KanaWardrobe.Strings.OP_werewolf="Вервольф"
KanaWardrobe.Strings.OP_MORPH_WEREWOLF="На панели вервольфа морф «%s» сменится на «%s»."
KanaWardrobe.Strings.OP_MORPH_UNKNOWN_WEREWOLF="На панели вервольфа изменится морф навыка «%s»."
KanaWardrobe.Strings.OP_REMOVE_WEREWOLF="«%s» будет убран с панели вервольфа, поскольку навык будет сброшен."

KanaWardrobe.Strings.PROBLEMS.skillWerewolfOnly="На панель вервольфа можно поставить только навыки вервольфа."
KanaWardrobe.Strings.OP_MOVE_FRONT="«%s» переместится в ячейку %d на первой панели."
KanaWardrobe.Strings.OP_MOVE_BACK="«%s» переместится в ячейку %d на второй панели."
KanaWardrobe.Strings.OP_MOVE_WEREWOLF="«%s» переместится в ячейку %d на панели вервольфа."

if GetCVar and GetCVar('language.2')=='ru'then
 local S=KanaWardrobe.Strings
 S.APPEARANCE='Внешний вид';S.CLEAR_appearance='Удалить внешний вид';S.OP_appearance='Выставить внешний вид';S.MISMATCH_appearance='Внешний вид'
 S.OP_APPEARANCE_COOLDOWN='Перезарядка внешнего вида: осталось %d с.'
 S.OP_APPEARANCE_RETRY='Внешний вид перезаряжается. Повтор через %d с.'
 S.OP_APPEARANCE_COOLDOWN_UNKNOWN='Ожидание перезарядки внешнего вида.'
 S.PROBLEMS.appearanceCooldownTimeout='Перезарядка внешнего вида не завершилась. Повторите этот шаг.'
 S.EMPTY_LIST='Создайте пресет на этой странице.';S.OUTCOME_quickSaved='Текущий билд сохранён в быструю ячейку.'
 S.APPEARANCE_MISMATCH='%s: должно быть «%s», сейчас «%s». Повторите этот шаг.'
 S.APPEARANCE_SAVE_HELP='Сохранить отмеченные категории и вернуть прежний внешний вид.'
 S.APPEARANCE_CANCEL_HELP='Отменить изменения пресета и вернуть прежний внешний вид.'
 S.APPEARANCE_CLOSE_HELP='Сохраните или отмените изменения пресета с возвратом прежнего внешнего вида либо продолжите редактирование.'
 S.OUTCOME_appearanceSaved='Пресет сохранён. Прежний внешний вид возвращён.'
 S.OUTCOME_appearanceCancelled='Редактирование отменено. Прежний внешний вид возвращён.'
 for key,value in pairs({COSTUME={'Костюм','Без костюма'},HAT={'Головной убор','Без головного убора'},HAIR={'Причёска','Без смены причёски'},
  FACIAL_HAIR_HORNS={'Растительность на лице и рога','Без смены растительности на лице и рогов'},FACIAL_ACCESSORY={'Аксессуар на лице','Без аксессуара на лице'},
  PIERCING_JEWELRY={'Украшения','Без украшений'},HEAD_MARKING={'Отметины на лице','Без отметин на лице'},BODY_MARKING={'Нательные отметины','Без нательных отметин'},
  SKIN={'Облик','Без облика'},POLYMORPH={'Превращение','Без превращения'},PERSONALITY={'Характер','Без характера'}})do
  S['APPEARANCE_'..key]=value[1];S['APPEARANCE_NONE_'..key]=value[2]
 end
 for key,value in pairs({appearanceUnavailable='Не удалось прочитать текущий внешний вид.',appearanceCategoryUnavailable='Эта категория внешнего вида недоступна.',
  appearanceWrongCategory='Сохранённый предмет относится к другой категории.',appearanceLocked='Сохранённый предмет ещё не открыт в коллекции.',
  appearanceBlocked='ESO сейчас не позволяет применить этот предмет.',appearanceUnconfirmed='ESO не применила изменение внешнего вида.'})do S.PROBLEMS[key]=value end
end

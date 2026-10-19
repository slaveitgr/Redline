# Snap Settings and application reset

Settings > System now implements the Adrenalin-style Snap Settings import/export action and a confirmed, scoped application reset. This is original Redline code using validated JSON; it does not import AMD's binary settings format.

A version-1 redline-ui-snapshot contains only supported UI preferences and serialized UiV6 settings: appearance, favorites, overlay, launch preferences and local backend choices. CoreCtrl hardware profiles, LACT GPU configuration, driver/service/repository configuration, Steam launch files, credentials and external application files are outside its scope. Import replaces the scoped application key set, defaulting absent preferences. Reset clears UiV6 and restores supported application defaults. Neither operation applies GPU/CPU profiles or edits Steam options.

Import is staged: the whole local file is read and validated before confirmation, with a 1 MiB limit, bounded entry/value sizes, a format/version check and scoped keys/types. The validated data is retained in memory, preventing a changed file from being silently imported after confirmation. Unknown settings and malformed values reject the complete import before mutation.

Import/reset must first create an atomic, importable backup in the application's data directory under snapshots/backups. Failure to create the backup prevents any settings change. The UI displays the backup path. A backup can itself be imported to restore the previous scoped key set. Preferences update the UI and generated overlay configuration through the existing application signals. External Steam options require their existing separate Apply/Restore workflow.

Tests verify export/import, exact scoped restore, malformed/foreign input rejection, staged data retention, backup creation, hardware-key preservation and no reset when backup creation fails. Native screenshots cover the About and Snap Settings windows. No hardware settings are changed by these tests.

About now identifies Slave IT Solutions — Greece and info@slave.gr / slave.gr, while preserving CoreCtrl and LACT attribution and the AMD non-affiliation statement.

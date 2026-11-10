const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
// The protocol check uses real roByteArray APIs and runs on Roku, not this interpreter.
for (const [sources, test, marker] of [
  [['source/hearthModel.brs'], 'scripts/hearthModel.test.brs', 'HEARTH_MODEL_TESTS_PASSED'],
  [['source/hearthModel.brs', 'source/hearthTheme.brs', 'source/hearthUi.brs', 'components/HearthHome.brs'], 'scripts/hearthHome.test.brs', 'HEARTH_HOME_TESTS_PASSED'],
  [['source/hearthModel.brs', 'components/HearthSettings.brs'], 'scripts/hearthSettings.test.brs', 'HEARTH_SETTINGS_TESTS_PASSED'],
  [['source/hearthModel.brs', 'components/HearthScene.brs'], 'scripts/hearthScene.test.brs', 'HEARTH_SCENE_TESTS_PASSED'],
  [['source/hearthModel.brs', 'source/hearthTheme.brs', 'source/hearthUi.brs', 'components/HearthControls.brs'], 'scripts/hearthControls.test.brs', 'HEARTH_CONTROLS_TESTS_PASSED'],
  [['source/hearthModel.brs', 'components/HearthTask.brs'], 'scripts/hearthTask.test.brs', 'HEARTH_TASK_TESTS_PASSED'],
  [['source/hearthModel.brs', 'source/hearthTheme.brs', 'source/haWebSocket.brs', 'components/HearthCameras.brs'], 'scripts/hearthCameras.test.brs', 'HEARTH_CAMERAS_TESTS_PASSED']
]) {
  const result = spawnSync(process.execPath, [
    require.resolve('brs/bin/cli.js'),
    '--component-dirs', 'components', ...sources, test
  ], { cwd: root, encoding: 'utf8' });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.error) console.error(result.error.message);
  // STOP may exit successfully; require the final assertion marker too.
  if (result.status !== 0 || !(result.stdout || '').includes(marker) || /Error occurred parsing/.test((result.stdout || '') + (result.stderr || ''))) process.exitCode = 1;
}

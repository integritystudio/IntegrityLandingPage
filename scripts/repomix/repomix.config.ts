import { defineConfig } from 'repomix';

const args = process.argv.slice(2);
const compress = args.includes('--compress');
const includeDiffs = args.includes('--include-diffs');
const includeLogs = args.includes('--include-logs');
const tokenCountTree = args.includes('--token-count-tree');

const filePath = compress
  ? 'docs/repomix/repo-compressed.xml'
  : 'docs/repomix/docs.xml';

export default defineConfig({
  output: {
    filePath,
    parsableStyle: true,
    showLineNumbers: true,
    compress,
    files: !tokenCountTree,
    git: {
      sortByChanges: true,
      includeDiffs,
      includeLogs,
      includeLogsCount: 20,
    },
  },
  include: ['lib/**/*', 'test/**/*', 'integration_test/**/*'],
  ignore: {
    useDefaultPatterns: true,
    customPatterns: ['tmp/', '*.log', 'dist/'],
  },
  security: {
    enableSecurityCheck: true,
  },
});

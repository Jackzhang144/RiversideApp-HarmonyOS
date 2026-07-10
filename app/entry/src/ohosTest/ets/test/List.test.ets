import appShellModelTest from './AppShellModel.test';
import jsonBoundaryTest from './JsonBoundary.test';

export default function tests(): void {
  appShellModelTest();
  jsonBoundaryTest();
}

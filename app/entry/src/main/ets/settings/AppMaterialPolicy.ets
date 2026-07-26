import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';
import { AppMaterialPreference } from './AppBehaviorSettings';

export function appMaterialEffect(
  preference: AppMaterialPreference,
  immersiveSupported: boolean
): SystemMaterialParams {
  if (preference === AppMaterialPreference.OFF) {
    return {
      materialType: hdsMaterial.MaterialType.NONE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
  }
  if (preference === AppMaterialPreference.EXQUISITE) {
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: immersiveSupported
        ? hdsMaterial.MaterialLevel.EXQUISITE
        : hdsMaterial.MaterialLevel.SMOOTH
    };
  }
  if (preference === AppMaterialPreference.GENTLE) {
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: immersiveSupported
        ? hdsMaterial.MaterialLevel.GENTLE
        : hdsMaterial.MaterialLevel.SMOOTH
    };
  }
  if (preference === AppMaterialPreference.SMOOTH) {
    return {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.SMOOTH
    };
  }
  return {
    materialType: hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  };
}

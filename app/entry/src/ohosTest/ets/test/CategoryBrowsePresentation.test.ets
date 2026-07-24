import { describe, expect, it } from '@ohos/hypium';
import {
  CategorySection,
  categorySections
} from '../../../main/ets/components/CategoryBrowsePresentation';
import { Category } from '../../../main/ets/models/ForumModels';

function category(
  id: number,
  name: string,
  position: number,
  parentCategoryId: number | null,
  subcategoryIds: Array<number> = []
): Category {
  return new Category(id, name, 'FFD400', '', position, parentCategoryId, subcategoryIds);
}

export default function categoryBrowsePresentationTest(): void {
  describe('Category browse presentation', () => {
    it('groups child boards under their clickable parent board', 0, () => {
      const parent: Category = category(10, '前程似锦', 1, null, [13, 11, 12]);
      const categories: Array<Category> = [
        parent,
        category(11, '就业创业', 1, 10),
        category(12, '出国留学', 2, 10),
        category(13, '保研考研', 3, 10),
        category(20, '科技学术', 2, null, [21]),
        category(21, '学术交流', 1, 20)
      ];

      const sections: Array<CategorySection> = categorySections(categories);

      expect(sections.length).assertEqual(2);
      expect(sections[0].parent.name).assertEqual('前程似锦');
      expect(sections[0].children.length).assertEqual(3);
      expect(sections[0].children[0].name).assertEqual('保研考研');
      expect(sections[0].children[1].name).assertEqual('就业创业');
      expect(sections[0].children[2].name).assertEqual('出国留学');
      expect(sections[1].parent.name).assertEqual('科技学术');
      expect(sections[1].children[0].name).assertEqual('学术交流');
    });

    it('prefers an explicit parent id and keeps orphaned boards visible', 0, () => {
      const categories: Array<Category> = [
        category(10, '父版块甲', 1, null, [30]),
        category(20, '父版块乙', 2, null, []),
        category(30, '明确属于乙', 1, 20),
        category(40, '孤立版块', 3, 999)
      ];

      const sections: Array<CategorySection> = categorySections(categories);

      expect(sections.length).assertEqual(3);
      expect(sections[0].children.length).assertEqual(0);
      expect(sections[1].children.length).assertEqual(1);
      expect(sections[1].children[0].name).assertEqual('明确属于乙');
      expect(sections[2].parent.name).assertEqual('孤立版块');
    });
  });
}

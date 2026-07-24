import { Category } from '../models/ForumModels';

export class CategorySection {
  public readonly parent: Category;
  public readonly children: Array<Category>;

  public constructor(parent: Category, children: Array<Category>) {
    this.parent = parent;
    this.children = children;
  }
}

function declaredChildIndex(parent: Category, category: Category): number {
  return parent.subcategoryIds.indexOf(category.id);
}

function compareChildren(parent: Category, left: Category, right: Category): number {
  const leftIndex: number = declaredChildIndex(parent, left);
  const rightIndex: number = declaredChildIndex(parent, right);
  if (leftIndex >= 0 && rightIndex >= 0 && leftIndex !== rightIndex) {
    return leftIndex - rightIndex;
  }
  if (leftIndex >= 0 && rightIndex < 0) {
    return -1;
  }
  if (leftIndex < 0 && rightIndex >= 0) {
    return 1;
  }
  if (left.position !== right.position) {
    return left.position - right.position;
  }
  return left.id - right.id;
}

function belongsTo(parent: Category, candidate: Category): boolean {
  if (candidate.id === parent.id) {
    return false;
  }
  if (candidate.parentCategoryId !== null) {
    return candidate.parentCategoryId === parent.id;
  }
  return parent.subcategoryIds.includes(candidate.id);
}

export function categorySections(categories: Array<Category>): Array<CategorySection> {
  const categoriesById: Map<number, Category> = new Map<number, Category>();
  for (const category of categories) {
    categoriesById.set(category.id, category);
  }

  const childIds: Set<number> = new Set<number>();
  for (const category of categories) {
    if (category.parentCategoryId !== null && categoriesById.has(category.parentCategoryId)) {
      childIds.add(category.id);
    } else {
      for (const parent of categories) {
        if (parent.id !== category.id && parent.subcategoryIds.includes(category.id)) {
          childIds.add(category.id);
          break;
        }
      }
    }
  }

  const sections: Array<CategorySection> = [];
  const displayedIds: Set<number> = new Set<number>();
  for (const category of categories) {
    if (childIds.has(category.id)) {
      continue;
    }
    const children: Array<Category> = categories.filter((candidate: Category): boolean => {
      return !displayedIds.has(candidate.id) && belongsTo(category, candidate);
    });
    children.sort((left: Category, right: Category): number => compareChildren(category, left, right));
    sections.push(new CategorySection(category, children));
    displayedIds.add(category.id);
    for (const child of children) {
      displayedIds.add(child.id);
    }
  }

  for (const category of categories) {
    if (!displayedIds.has(category.id)) {
      sections.push(new CategorySection(category, []));
      displayedIds.add(category.id);
    }
  }
  return sections;
}

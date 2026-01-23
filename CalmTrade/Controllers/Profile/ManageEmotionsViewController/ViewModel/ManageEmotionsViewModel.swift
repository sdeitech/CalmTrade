//
//  ManageEmotionsViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 21/01/26.
//

import Foundation

final class ManageEmotionsViewModel {

    // MARK: - Output
    var onReload: (() -> Void)?
    var onError: ((String) -> Void)?

    // MARK: - State
    private(set) var categories: [EmotionCategoryModel] = []

    private let maxRows = 5

    // MARK: - Fetch
    func fetchTags() {
        APIService().startService(
            with: .GET,
            path: "emotionalTags/tags",
            parameters: nil,
            files: nil,
            modelType: EmotionTagsResponse.self
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .Success(let res):
                    guard let cats = res?.categories else { return }
                    self.map(cats)
                    self.onReload?()

                case .Error(let msg):
                    self.onError?(msg)
                }
            }
        }
    }

    private func map(_ dtos: [EmotionCategoryDTO]) {
        categories = dtos.map {
            EmotionCategoryModel(
                id: $0.id,
                name: $0.name,
                colorHex: $0.colorCode,
                tags: $0.tags.prefix(maxRows).map {
                    EmotionTagModel(id: $0.id ?? UUID().uuidString, name: $0.name)
                }
            )
        }
    }

    // MARK: - Helpers
    func numberOfSections() -> Int { categories.count }
    func numberOfRows(in section: Int) -> Int { maxRows }

    func tag(at indexPath: IndexPath) -> EmotionTagModel? {
        let tags = categories[indexPath.section].tags
        return indexPath.row < tags.count ? tags[indexPath.row] : nil
    }

    func category(at section: Int) -> EmotionCategoryModel {
        categories[section]
    }

    // MARK: - CRUD
    func createTag(name: String, section: Int) {
        let categoryId = categories[section].id

        APIService().startService(
            with: .POST,
            path: "emotionalTags/user/create-tag?categoryId=\(categoryId)",
            parameters: ["name": name],
            files: nil,
            modelType: EmptyResponse.self
        ) { [weak self] _ in
            self?.fetchTags()
        }
    }

    func updateTag(name: String, section: Int, row: Int) {
        let category = categories[section]
        let tag = category.tags[row]

        let path = "emotionalTags/user/update-tag?categoryId=\(category.id)&tagId=\(tag.id)"

        APIService().startService(
            with: .PATCH,
            path: path,
            parameters: ["name": name],
            files: nil,
            modelType: EmptyResponse.self
        ) { [weak self] _ in
            self?.fetchTags()
        }
    }

    func deleteTag(section: Int, row: Int) {
        let category = categories[section]
        let tag = category.tags[row]

        let path = "emotionalTags/user/delete-tag?categoryId=\(category.id)&tagId=\(tag.id)"

        APIService().startService(
            with: .DELETE,
            path: path,
            parameters: nil,
            files: nil,
            modelType: EmptyResponse.self
        ) { [weak self] _ in
            self?.fetchTags()
        }
    }
}

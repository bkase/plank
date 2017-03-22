//
//  FileGenerator.swift
//  Plank
//
//  Created by Rahul Malik on 7/23/15.
//  Copyright © 2015 Rahul Malik. All rights reserved.
//

import Foundation

public typealias GenerationParameters = [GenerationParameterType:String]

let formatter = DateFormatter()
let date = Date()

public enum GenerationParameterType {
    case classPrefix
    case recursive
    case includeRuntime
}

protocol FileGeneratorManager {
    static func filesToGenerate(descriptor: SchemaObjectRoot, generatorParameters: GenerationParameters) -> [FileGenerator]
}

protocol FileGenerator {
    func renderFile() -> String
    var fileName: String { mutating get }
}

protocol FilePrinter {
    func print(statement: String)
}

extension FileGenerator {

    func renderCommentHeader() -> String {
        formatter.dateStyle = DateFormatter.Style.long
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "MM-dd-yyyy 'at' HH:mm:ss"

        var copy = self

        let header = [
            "//",
            "//  \(copy.fileName)",
            "//  Autogenerated by plank",
            "//",
            "//  DO NOT EDIT - EDITS WILL BE OVERWRITTEN",
            "//  @generated",
            "//"
        ]

        return header.joined(separator: "\n")
    }

}

func generateFile(_ schema: SchemaObjectRoot, outputDirectory: URL, generationParameters: GenerationParameters) {
    for var file in ObjectiveCFileGenerator.filesToGenerate(descriptor: schema, generatorParameters: generationParameters) {
        let fileContents = file.renderFile() + "\n" // Ensure there is exactly one new line a the end of the file
        do {
            try fileContents.write(
                to: URL(string: file.fileName, relativeTo: outputDirectory)!,
                atomically: true,
                encoding: String.Encoding.utf8)
        } catch {
            assert(false)
        }
    }
}

public func generateFileRuntime(outputDirectory: URL) {
    let files: [FileGenerator] = [ObjCRuntimeHeaderFile(), ObjCRuntimeImplementationFile()]
    for var file in files {
        let fileContents = file.renderFile() + "\n" // Ensure there is exactly one new line a the end of the file
        do {
            try fileContents.write(
                to: URL(string: file.fileName, relativeTo: outputDirectory)!,
                atomically: true,
                encoding: String.Encoding.utf8)
        } catch {
            assert(false)
        }
    }
}

public func loadSchemasForUrls(urls: Set<URL>) -> [(URL, Schema)] {
    return urls.map { ($0, FileSchemaLoader.sharedInstance.loadSchema($0)) }
}

public func generateDeps(urls: Set<URL>) {
    let urlSchemas = loadSchemasForUrls(urls: urls)
    let deps = Set(urlSchemas.map { (url, schema) -> String in
        ([url] + schema.deps()).map { $0.path }.joined(separator: ":")
    })
    deps.forEach { dep in
        print(dep)
    }
}

public func generateFiles(urls: Set<URL>, outputDirectory: URL, generationParameters: GenerationParameters) {
    _ = loadSchemasForUrls(urls: urls)
    var processedSchemas = Set<URL>([])
    repeat {
        let _ = FileSchemaLoader.sharedInstance.refs.map({ (url: URL, schema: Schema) -> Void in
            if processedSchemas.contains(url) {
                return
            }
            processedSchemas.insert(url)
            switch schema {
            case .Object(let rootObject):
                generateFile(rootObject,
                             outputDirectory: outputDirectory,
                             generationParameters: generationParameters)
            default:
                assert(false, "Incorrect Schema for root") // TODO Better error message.
            }
        })
    } while (
        generationParameters[.recursive] != nil &&
        processedSchemas.count != FileSchemaLoader.sharedInstance.refs.keys.count)
    if generationParameters[.includeRuntime] != nil {
        generateFileRuntime(outputDirectory: outputDirectory)
    }
}

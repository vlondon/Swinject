//
//  ContainerSpec.swift
//  Swinject
//
//  Created by Yoichi Tagaya on 7/23/15.
//  Copyright © 2015 Swinject Contributors. All rights reserved.
//

import Quick
import Nimble
@testable import Swinject

class ContainerSpec: QuickSpec {
    override func spec() {
        var container: Container!
        beforeEach {
            container = Container()
        }
        
        describe("Resolution of a non-registered service") {
            it("returns nil.") {
                let animal = container.resolve(AnimalType.self)
                expect(animal).to(beNil())
            }
        }
        describe("Resolution of the same service") {
            it("resolves by arguments.") {
                container.register(AnimalType.self) { _ in Cat() }
                container.register(AnimalType.self) { _, arg in Cat(name: arg) }
                container.register(AnimalType.self) { _, arg1, arg2 in Cat(name: arg1, sleeping: arg2) }
                
                let noname = container.resolve(AnimalType.self) as! Cat
                let mimi = container.resolve(AnimalType.self, argument: "Mimi") as! Cat
                let mew = container.resolve(AnimalType.self, arguments: "Mew", true) as! Cat
                expect(noname.name).to(beNil())
                expect(mimi.name) == "Mimi"
                expect(mew.name) == "Mew"
                expect(mew.sleeping) == true
            }
            it("resolves by the registered name.") {
                container.register(AnimalType.self, name: "RegMimi") { _ in Cat(name: "Mimi") }
                container.register(AnimalType.self, name: "RegMew") { _ in Cat(name: "Mew") }
                container.register(AnimalType.self) { _ in Cat() }
                
                let mimi = container.resolve(AnimalType.self, name: "RegMimi") as! Cat
                let mew = container.resolve(AnimalType.self, name: "RegMew") as! Cat
                let noname = container.resolve(AnimalType.self) as! Cat
                expect(mimi.name) == "Mimi"
                expect(mew.name) == "Mew"
                expect(noname.name).to(beNil())
            }
        }
        describe("Removal of registered services") {
            it("can remove all registered services.") {
                container.register(AnimalType.self, name: "RegMimi") { _ in Cat(name: "Mimi") }
                container.register(AnimalType.self, name: "RegMew") { _ in Cat(name: "Mew") }
                container.removeAll()
                
                let mimi = container.resolve(AnimalType.self, name: "RegMimi")
                let mew = container.resolve(AnimalType.self, name: "RegMew")
                expect(mimi).to(beNil())
                expect(mew).to(beNil())
            }
        }
        describe("Container hierarchy") {
            it("resolves a service registered on the parent container.") {
                let parent = Container()
                parent.register(AnimalType.self) { _ in Cat() }
                let child = Container(parent: parent)
                
                let cat = child.resolve(AnimalType.self)
                expect(cat).notTo(beNil())
            }
            it("does not resolve a service registred on the child container.") {
                let parent = Container()
                let child = Container(parent: parent)
                child.register(AnimalType.self) { _ in Cat() }
                
                let cat = parent.resolve(AnimalType.self)
                expect(cat).to(beNil())
            }
        }
        describe("Scope") {
            let registerCatAndPetOwnerDependingOnFood: (Container) -> Void = {
                $0.register(AnimalType.self) {
                    let cat = Cat()
                    cat.favoriteFood = $0.resolve(FoodType.self)
                    return cat
                }
                $0.register(PersonType.self) {
                    let owner = PetOwner(pet: $0.resolve(AnimalType.self)!)
                    owner.favoriteFood = $0.resolve(FoodType.self)
                    return owner
                }
            }
            
            context("in transient scope") {
                it("does not have a shared object in a container.") {
                    container.register(AnimalType.self) { _ in Cat() }
                        .inObjectScope(.transient)
                    
                    let cat1 = container.resolve(AnimalType.self) as! Cat
                    let cat2 = container.resolve(AnimalType.self) as! Cat
                    expect(cat1 !== cat2).to(beTrue()) // Workaround for crash in Nimble.
                }
                it("resolves a service to new objects in a graph") {
                    registerCatAndPetOwnerDependingOnFood(container)
                    container.register(FoodType.self) { _ in Sushi() }
                        .inObjectScope(.transient)
                    
                    let owner = container.resolve(PersonType.self) as! PetOwner
                    let ownersSushi = owner.favoriteFood as! Sushi
                    let catsSushi = (owner.pet as! Cat).favoriteFood as! Sushi
                    expect(ownersSushi !== catsSushi).to(beTrue()) // Workaround for crash in Nimble.
                }
            }
            context("in graph scope") {
                it("does not have a shared object in a container.") {
                    container.register(AnimalType.self) { _ in Cat() }
                        .inObjectScope(.graph)
                    
                    let cat1 = container.resolve(AnimalType.self) as! Cat
                    let cat2 = container.resolve(AnimalType.self) as! Cat
                    expect(cat1 !== cat2).to(beTrue()) // Workaround for crash in Nimble.
                }
                it("resolves a service to the same object in a graph") {
                    registerCatAndPetOwnerDependingOnFood(container)
                    container.register(FoodType.self) { _ in Sushi() }
                        .inObjectScope(.graph)
                    
                    let owner = container.resolve(PersonType.self) as! PetOwner
                    let ownersSushi = owner.favoriteFood as! Sushi
                    let catsSushi = (owner.pet as! Cat).favoriteFood as! Sushi
                    expect(ownersSushi === catsSushi).to(beTrue()) // Workaround for crash in Nimble.
                }
            }
            context("in container scope") {
                it("shares an object in the own container.") {
                    container.register(AnimalType.self) { _ in Cat() }
                        .inObjectScope(.container)

                    let cat1 = container.resolve(AnimalType.self) as! Cat
                    let cat2 = container.resolve(AnimalType.self) as! Cat
                    expect(cat1 === cat2).to(beTrue()) // Workaround for crash in Nimble.
                }
                it("shares an object from a parent container to its child.") {
                    let parent = Container()
                    parent.register(AnimalType.self) { _ in Cat() }
                        .inObjectScope(.container)
                    parent.register(AnimalType.self, name: "dog") { _ in Dog() }
                        .inObjectScope(.container)
                    let child = Container(parent: parent)

                    // Case resolving on the parent first.
                    let cat1 = parent.resolve(AnimalType.self) as! Cat
                    let cat2 = child.resolve(AnimalType.self) as! Cat
                    expect(cat1 === cat2).to(beTrue()) // Workaround for crash in Nimble.

                    // Case resolving on the child first.
                    let dog1 = child.resolve(AnimalType.self, name: "dog") as! Dog
                    let dog2 = parent.resolve(AnimalType.self, name: "dog") as! Dog
                    expect(dog1 === dog2).to(beTrue()) // Workaround for crash in Nimble.
                }
                it("resolves a service in the parent container to the same object in a graph") {
                    let parent = Container()
                    parent.register(FoodType.self) { _ in Sushi() }
                        .inObjectScope(.container)
                    let child = Container(parent: parent)
                    registerCatAndPetOwnerDependingOnFood(child)

                    let owner = child.resolve(PersonType.self) as! PetOwner
                    let ownersSushi = owner.favoriteFood as! Sushi
                    let catsSushi = (owner.pet as! Cat).favoriteFood as! Sushi
                    expect(ownersSushi === catsSushi).to(beTrue()) // Workaround for crash in Nimble.
                }
            }
        }
        describe("Init completed event") {
            it("raises the event when a new instance is created.") {
                var eventRaised = false
                container.register(AnimalType.self) { _ in Cat() }
                    .initCompleted { _, _ in eventRaised = true }
                
                let cat = container.resolve(AnimalType.self)
                expect(cat).notTo(beNil())
                expect(eventRaised) == true
            }
        }
        describe("Injection types") {
            it("accepts initializer injection.") {
                container.register(AnimalType.self) { _ in Cat() }
                container.register(PersonType.self) { r in PetOwner(pet: r.resolve(AnimalType.self)!) }
                
                let owner = container.resolve(PersonType.self) as! PetOwner
                expect(owner.pet).notTo(beNil())
            }
            it("accepts property injection in registration.") {
                container.register(AnimalType.self) { _ in Cat() }
                container.register(PersonType.self) { r in
                    let owner = PetOwner()
                    owner.pet = r.resolve(AnimalType.self)!
                    return owner
                }
                
                let owner = container.resolve(PersonType.self) as! PetOwner
                expect(owner.pet).notTo(beNil())
            }
            it("accepts property injection in initCompleted event.") {
                container.register(AnimalType.self) { _ in Cat() }
                container.register(PersonType.self) { _ in PetOwner() }
                    .initCompleted { r, s in
                        let owner = s as! PetOwner
                        owner.pet = r.resolve(AnimalType.self)!
                    }
                
                let owner = container.resolve(PersonType.self) as! PetOwner
                expect(owner.pet).notTo(beNil())
            }
            it("accepts method injection in registration.") {
                container.register(AnimalType.self) { _ in Cat() }
                container.register(PersonType.self) { r in
                    let owner = PetOwner()
                    owner.injectAnimal(r.resolve(AnimalType.self)!)
                    return owner
                }
                
                let owner = container.resolve(PersonType.self) as! PetOwner
                expect(owner.pet).notTo(beNil())
            }
            it("accepts method injection in initCompleted event.") {
                container.register(AnimalType.self) { _ in Cat() }
                container.register(PersonType.self) { _ in PetOwner() }
                    .initCompleted { r, s in
                        let owner = s as! PetOwner
                        owner.injectAnimal(r.resolve(AnimalType.self)!)
                    }
                
                let owner = container.resolve(PersonType.self) as! PetOwner
                expect(owner.pet).notTo(beNil())
            }
        }
        describe("Value type resolution") {
            it("resolves struct instances ignoring object scopes.") {
                let runInObjectScope: (ObjectScope) -> Void = { scope in
                    container.removeAll()
                    container.register(AnimalType.self) { _ in Turtle(name: "Ninja") }
                        .inObjectScope(scope)
                    var turtle1 = container.resolve(AnimalType.self)!
                    var turtle2 = container.resolve(AnimalType.self)!
                    turtle1.name = "Samurai"
                    expect(turtle1.name) == "Samurai"
                    expect(turtle2.name) == "Ninja"
                }
                
                runInObjectScope(.transient)
                runInObjectScope(.graph)
                runInObjectScope(.container)
            }
            it("resolves struct instances defined in the parent container ignoring object scopes.") {
                let runInObjectScope: (ObjectScope) -> Void = { scope in
                    container.removeAll()
                    container.register(AnimalType.self) { _ in Turtle(name: "Ninja") }
                        .inObjectScope(scope)
                    let childContainer = Container(parent: container)
                    
                    var turtle1 = childContainer.resolve(AnimalType.self)!
                    var turtle2 = childContainer.resolve(AnimalType.self)!
                    turtle1.name = "Samurai"
                    expect(turtle1.name) == "Samurai"
                    expect(turtle2.name) == "Ninja"
                }
                
                runInObjectScope(.transient)
                runInObjectScope(.graph)
                runInObjectScope(.container)
            }
            it("resolves only once if object scope is container or hierarchy to simulate singleton (instantiation only once).") {
                let runInObjectScope: (ObjectScope, Int) -> Void = { scope, expectation in
                    var invokedCount = 0
                    container.removeAll()
                    container.register(AnimalType.self) { _ in
                        invokedCount += 1
                        return Turtle(name: "Ninja")
                    }.inObjectScope(scope)
                    _ = container.resolve(AnimalType.self)!
                    _ = container.resolve(AnimalType.self)!
                    expect(invokedCount) == expectation
                }
                
                runInObjectScope(.transient, 2)
                runInObjectScope(.graph, 2)
                runInObjectScope(.container, 1)
            }
        }
        describe("Class as a service type") {
            it("resolves a registred subclass of a service type class.") {
                container.register(Cat.self) { _ in Siamese(name: "Siam") }
                
                let siam = container.resolve(Cat.self) as! Siamese
                expect(siam.name) == "Siam"
            }
            it("resolves a self-binding with dependency injected.") {
                container.register(PetOwner.self) { r in PetOwner(pet: r.resolve(AnimalType.self)!) }
                container.register(AnimalType.self) { _ in Siamese(name: "Siam") }
                
                let owner = container.resolve(PetOwner.self)!
                let siam = owner.pet as! Siamese
                expect(siam.name) == "Siam"
            }
        }
        describe("Convenience initializers") {
            it("takes a closure registering services.") {
                let container = Container() {
                    $0.register(AnimalType.self) { _ in Cat() }
                }
                
                expect(container.resolve(AnimalType.self) as? Cat).notTo(beNil())
            }
        }
        
        describe("CustomStringConvertible") {
            it("describes empty description without service registrations.") {
                expect(container.description) == "[\n]"
            }
            it("describes a registration.") {
                container.register(AnimalType.self) { _ in Cat() }
                
                expect(container.description) ==
                    "[\n"
                    + "    { Service: AnimalType, Factory: (Resolver) -> AnimalType, ObjectScope: graph }\n"
                    + "]"
            }
            it("describes a registration with name.") {
                container.register(AnimalType.self, name: "My Cat") { _ in Cat() }
                
                expect(container.description) ==
                    "[\n"
                    + "    { Service: AnimalType, Name: \"My Cat\", Factory: (Resolver) -> AnimalType, ObjectScope: graph }\n"
                    + "]"
            }
            it("describes a registration with arguments.") {
                container.register(AnimalType.self) { _, arg1, arg2 in Cat(name: arg1, sleeping: arg2) }
                
                expect(container.description) ==
                    "[\n"
                    + "    { Service: AnimalType, Factory: ((Resolver, String, Bool)) -> AnimalType, ObjectScope: graph }\n"
                    + "]"
            }
            it("describes a registration with a specified object scope.") {
                container.register(AnimalType.self) { _ in Cat() }
                    .inObjectScope(.container)
                
                expect(container.description) ==
                    "[\n"
                    + "    { Service: AnimalType, Factory: (Resolver) -> AnimalType, ObjectScope: container }\n"
                    + "]"
            }
            it("describes a registration with initCompleted.") {
                container.register(AnimalType.self) { _ in Cat() }
                    .initCompleted { _, _ in }
                
                expect(container.description) ==
                    "[\n"
                    + "    { Service: AnimalType, Factory: (Resolver) -> AnimalType, ObjectScope: graph, InitCompleted: Specified }\n"
                    + "]"
            }
            it("describes multiple registrations.") {
                container.register(AnimalType.self, name: "1") { _ in Cat() }
                container.register(AnimalType.self, name: "2") { _ in Cat() }
                
                expect(container.description) ==
                    "[\n"
                    + "    { Service: AnimalType, Name: \"1\", Factory: (Resolver) -> AnimalType, ObjectScope: graph },\n"
                    + "    { Service: AnimalType, Name: \"2\", Factory: (Resolver) -> AnimalType, ObjectScope: graph }\n"
                    + "]"
            }
        }
    }
}

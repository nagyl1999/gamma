/********************************************************************************
 * Copyright (c) 2018-2020 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.statechart.lowlevel.transformation

import hu.bme.mit.gamma.expression.model.BinaryExpression
import hu.bme.mit.gamma.expression.model.BooleanTypeDefinition
import hu.bme.mit.gamma.expression.model.ConstantDeclaration
import hu.bme.mit.gamma.expression.model.DecimalTypeDefinition
import hu.bme.mit.gamma.expression.model.DefaultExpression
import hu.bme.mit.gamma.expression.model.DirectReferenceExpression
import hu.bme.mit.gamma.expression.model.EnumerationLiteralExpression
import hu.bme.mit.gamma.expression.model.EnumerationTypeDefinition
import hu.bme.mit.gamma.expression.model.Expression
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory
import hu.bme.mit.gamma.expression.model.FunctionAccessExpression
import hu.bme.mit.gamma.expression.model.IfThenElseExpression
import hu.bme.mit.gamma.expression.model.IntegerTypeDefinition
import hu.bme.mit.gamma.expression.model.MultiaryExpression
import hu.bme.mit.gamma.expression.model.NullaryExpression
import hu.bme.mit.gamma.expression.model.ParameterDeclaration
import hu.bme.mit.gamma.expression.model.RationalTypeDefinition
import hu.bme.mit.gamma.expression.model.Type
import hu.bme.mit.gamma.expression.model.TypeDeclaration
import hu.bme.mit.gamma.expression.model.TypeReference
import hu.bme.mit.gamma.expression.model.UnaryExpression
import hu.bme.mit.gamma.expression.model.VariableDeclaration
import hu.bme.mit.gamma.statechart.interface_.EventParameterReferenceExpression
import hu.bme.mit.gamma.statechart.lowlevel.model.EventDirection
import hu.bme.mit.gamma.util.GammaEcoreUtil

import static com.google.common.base.Preconditions.checkState
import static extension com.google.common.collect.Iterables.getOnlyElement
import static hu.bme.mit.gamma.xsts.transformation.util.Namings.*

import static extension hu.bme.mit.gamma.expression.derivedfeatures.ExpressionModelDerivedFeatures.*
import hu.bme.mit.gamma.expression.model.RecordTypeDefinition
import hu.bme.mit.gamma.expression.model.TypeDefinition
import java.util.List
import java.util.ArrayList
import hu.bme.mit.gamma.expression.model.FieldDeclaration
import hu.bme.mit.gamma.expression.model.RecordLiteralExpression
import hu.bme.mit.gamma.expression.model.ArrayTypeDefinition
import hu.bme.mit.gamma.expression.model.ArrayLiteralExpression
import hu.bme.mit.gamma.expression.model.IntegerLiteralExpression
import hu.bme.mit.gamma.expression.model.RecordAccessExpression
import hu.bme.mit.gamma.expression.model.ReferenceExpression
import hu.bme.mit.gamma.expression.model.ArrayAccessExpression
import hu.bme.mit.gamma.expression.model.SelectExpression
import hu.bme.mit.gamma.expression.model.Declaration

class ExpressionTransformer {
	// Auxiliary object
	protected final extension GammaEcoreUtil gammaEcoreUtil = GammaEcoreUtil.INSTANCE
	// Expression factory
	protected final extension ExpressionModelFactory constraintFactory = ExpressionModelFactory.eINSTANCE
	// Trace needed for variable mappings
	protected final Trace trace
	protected final boolean functionInlining
	
	new(Trace trace, boolean functionInlining) {
		this.trace = trace
		this.functionInlining = functionInlining
	}
	
	def dispatch List<Expression> transformExpression(NullaryExpression expression) {
		var result = new ArrayList<Expression>
		result += expression.clone(true, true)
		return result
	}
	
	def dispatch List<Expression> transformExpression(DefaultExpression expression) {
		var result = new ArrayList<Expression>
		result += createTrueExpression
		return result
	}
	
	def dispatch List<Expression> transformExpression(FunctionAccessExpression expression) {
		var result = new ArrayList<Expression>
		if (functionInlining) {
			for (elem : trace.get(expression)) {
				result += createDirectReferenceExpression => [
					it.declaration = elem
				]
			}
		} else {
			//TODO no inlining
			throw new IllegalArgumentException("Currently only function inlining is possible!")
		}
		return result
	}
	
	def dispatch List<Expression> transformExpression(RecordAccessExpression expression) {
		throw new IllegalArgumentException("Currently only function inlining is possible!")
		
		
	}
	
	def dispatch List<Expression> transformExpression(UnaryExpression expression) {
		var result = new ArrayList<Expression>
		result += create(expression.eClass) as UnaryExpression => [
			it.operand = expression.operand.transformExpression.getOnlyElement
		]
		return result
	}
	
	def dispatch List<Expression> transformExpression(IfThenElseExpression expression) {
		var result = new ArrayList<Expression>
		result += createIfThenElseExpression => [
			it.condition = expression.condition.transformExpression.getOnlyElement
			it.then = expression.then.transformExpression.getOnlyElement
			it.^else = expression.^else.transformExpression.getOnlyElement
		]
		return result
	}

	// Key method
	def dispatch List<Expression> transformExpression(DirectReferenceExpression expression) {
		var result = new ArrayList<Expression>
		val declaration = expression.declaration
		if (declaration instanceof ConstantDeclaration) {
			// TODO complex types
			// Constant type declarations have to be transformed as their right hand side is inlined
			val constantType = declaration.type
			if (constantType instanceof TypeReference) {
				val constantTypeDeclaration = constantType.reference
				val typeDefinition = constantTypeDeclaration.type
				if (!typeDefinition.isPrimitive) {
					if (!trace.isMapped(constantTypeDeclaration)) {
						val transformedTypeDeclaration = constantTypeDeclaration.transformTypeDeclaration
						val lowlevelPackage = trace.lowlevelPackage
						lowlevelPackage.typeDeclarations += transformedTypeDeclaration
					}
				}
			}
			result += declaration.expression.transformExpression
		} else {
			checkState(declaration instanceof VariableDeclaration || 
				declaration instanceof ParameterDeclaration, declaration)
			if (declaration instanceof VariableDeclaration) {
				if (trace.get(declaration) !== null) {	//try to get as simple
					result += createDirectReferenceExpression => [
						it.declaration = trace.get(declaration)
					]	
				} else {								//if no result as simple, try as complex
					var mapKeys = exploreComplexType(declaration, declaration.type.typeDefinitionFromType, new ArrayList<FieldDeclaration>)
					for (key : mapKeys) {
						result += createDirectReferenceExpression => [
							it.declaration = trace.get(key)
						]
					}
				}
			}
			else if (declaration instanceof ParameterDeclaration) {
				//TODO complex types
				checkState(trace.isMapped(declaration), declaration)
				result += createDirectReferenceExpression => [
					it.declaration = trace.get(declaration)
				]
			}
		}
		return result
	}
	
	// Key method
	def dispatch List<Expression> transformExpression(EnumerationLiteralExpression expression) {
		var result = new ArrayList<Expression>
		val gammaEnumLiteral = expression.reference
		val index = gammaEnumLiteral.index
		val gammaEnumTypeDeclaration = gammaEnumLiteral.getContainerOfType(TypeDeclaration)
		checkState(trace.isMapped(gammaEnumTypeDeclaration))
		val lowlevelEnumTypeDeclaration = trace.get(gammaEnumTypeDeclaration)
		val lowlevelEnumTypeDefinition = lowlevelEnumTypeDeclaration.type as EnumerationTypeDefinition
		result += createEnumerationLiteralExpression => [
			it.reference = lowlevelEnumTypeDefinition.literals.get(index)
		]
		return result
	}
	
	// Key method
	def dispatch List<Expression> transformExpression(RecordLiteralExpression expression) {
		//TODO currently the field assignment position has to match the field declaration position
		var result = new ArrayList<Expression>
		for (assignment : expression.fieldAssignments) {
			result += assignment.value.transformExpression
		}
		return result
	}
	
	// Key method
	def dispatch List<Expression> transformExpression(EventParameterReferenceExpression expression) {
		var result = new ArrayList<Expression>
		val port = expression.port
		val event = expression.event
		val parameter = expression.parameter
		result +=  createDirectReferenceExpression => [
			it.declaration = trace.get(port, event, parameter).get(EventDirection.IN)
		]
		return result
	}
	
	def dispatch List<Expression> transformExpression(BinaryExpression expression) {
		var result = new ArrayList<Expression>
		result += create(expression.eClass) as BinaryExpression => [
			it.leftOperand = expression.leftOperand.transformExpression.getOnlyElement
			it.rightOperand = expression.rightOperand.transformExpression.getOnlyElement
		]
		return result
	}
	
	def dispatch List<Expression> transformExpression(MultiaryExpression expression) {
		var result = new ArrayList<Expression>
		val newExpression = create(expression.eClass) as MultiaryExpression
		for (containedExpression : expression.operands) {
			newExpression.operands += containedExpression.transformExpression.getOnlyElement
		}
		result += newExpression
		return result
	}
	
	protected def dispatch Type transformType(Type type) {
		throw new IllegalArgumentException("Not known type: " + type)
	}

	protected def dispatch Type transformType(BooleanTypeDefinition type) {
		return type.clone(true, true)
	}

	protected def dispatch Type transformType(IntegerTypeDefinition type) {
		return type.clone(true, true)
	}

	protected def dispatch Type transformType(DecimalTypeDefinition type) {
		return type.clone(true, true)
	}
	
	protected def dispatch Type transformType(RationalTypeDefinition type) {
		return type.clone(true, true)
	}
	
	protected def dispatch Type transformType(EnumerationTypeDefinition type) {
		return type.clone(true, true)
	}
	
	//TODO check maybe?
	protected def dispatch Type transformType(ArrayTypeDefinition type) {
		return type.clone(true, true)
	}
	
	protected def dispatch Type transformType(TypeReference type) {
		val typeDeclaration = type.reference
		val typeDefinition = typeDeclaration.type
		// Inlining primitive types
		if (typeDefinition.isPrimitive) {
			return typeDefinition.transformType
		}
		val lowlevelTypeDeclaration = if (trace.isMapped(typeDeclaration)) {
			trace.get(typeDeclaration)
		}
		else {
			// Transforming type declaration
			val transformedTypeDeclaration = typeDeclaration.transformTypeDeclaration
			val lowlevelPackage = trace.lowlevelPackage
			lowlevelPackage.typeDeclarations += transformedTypeDeclaration
			transformedTypeDeclaration
		}
		return createTypeReference => [
			it.reference = lowlevelTypeDeclaration
		]
	}
	
	protected def transformTypeDeclaration(TypeDeclaration typeDeclaration) {
		val newTypeDeclaration = constraintFactory.create(typeDeclaration.eClass) as TypeDeclaration => [
			it.name = getName(typeDeclaration)
			it.type = typeDeclaration.type.transformType
		]
		trace.put(typeDeclaration, newTypeDeclaration)
		return newTypeDeclaration
	}
	
	protected def List<VariableDeclaration> transformVariable(VariableDeclaration variable) {
		var List<VariableDeclaration> transformed = new ArrayList<VariableDeclaration>()
		var TypeDefinition variableType = getTypeDefinitionFromType(variable.type)
		// Records are broken up into separate variables
		if (variableType instanceof RecordTypeDefinition) {
			var RecordTypeDefinition typeDef = getTypeDefinitionFromType(variable.type) as RecordTypeDefinition
			for (field : typeDef.fieldDeclarations) {
				var innerField = new ArrayList<FieldDeclaration>
				innerField.add(field)
				transformed.addAll(transformVariableField(variable, innerField, new ArrayList<ArrayTypeDefinition>))
			}
			return transformed
		} else if (variableType instanceof ArrayTypeDefinition) {
			var arrayStack = new ArrayList<ArrayTypeDefinition>
			arrayStack.add(variableType)
			transformed.addAll(transformVariableArray(variable, variableType, arrayStack))
			return transformed
		} else {	//Simple variables and arrays of simple types are simply transformed
			transformed.add(createVariableDeclaration => [
				it.name = variable.name
				it.type = variable.type.transformType
				it.expression = variable.expression?.transformExpression?.getOnlyElement
			])
			trace.put(variable, transformed.head)
			return transformed
		}
	}
	
	private def List<VariableDeclaration> transformVariableField(VariableDeclaration variable, List<FieldDeclaration> currentField, List<ArrayTypeDefinition> arrayStack) {
		var List<VariableDeclaration> transformed = new ArrayList()
		
		if (getTypeDefinitionFromType(currentField.last.type) instanceof RecordTypeDefinition
		) {			// if another record
			var RecordTypeDefinition typeDef = getTypeDefinitionFromType(currentField.last.type) as RecordTypeDefinition
			for (field : typeDef.fieldDeclarations) {
				var innerField = new ArrayList<FieldDeclaration>
				innerField.addAll(currentField)
				innerField.add(field)
				var innerStack = new ArrayList<ArrayTypeDefinition>
				innerStack.addAll(arrayStack)
				transformed.addAll(transformVariableField(variable, innerField, innerStack))
			}
		} else {	//if simple type
			var transformedField = createVariableDeclaration => [
				it.name = variable.name + "_" + currentField.last.name
				
				it.type = createTransformedRecordType(arrayStack, currentField.last.type)
				if (variable.expression !== null) {
					var Expression initial = variable.expression
					if (initial instanceof RecordLiteralExpression) {
						it.expression = getExpressionFromRecordLiteral(initial, currentField).transformExpression.getOnlyElement
					} else if (initial instanceof ArrayLiteralExpression) {
						it.expression = constraintFactory.createArrayLiteralExpression
						for (op : initial.operands) {
							if (op instanceof RecordLiteralExpression) {
								(it.expression as ArrayLiteralExpression).operands.add(getExpressionFromRecordLiteral(op, currentField).transformExpression.getOnlyElement)
							}
						}
					}
				}
			]
			transformed.add(transformedField)
			trace.put(new Pair<VariableDeclaration, List<FieldDeclaration>>(variable,currentField), transformedField)
		}
		
		return transformed
	}
	
	private def List<VariableDeclaration> transformVariableArray(VariableDeclaration variable, ArrayTypeDefinition currentType, List<ArrayTypeDefinition> arrayStack) {
		var List<VariableDeclaration> transformed = new ArrayList<VariableDeclaration>()
		
		var TypeDefinition innerType = getTypeDefinitionFromType(currentType.elementType)
		if (innerType instanceof ArrayTypeDefinition) {
			var innerStack = new ArrayList<ArrayTypeDefinition>
			innerStack.addAll(arrayStack)
			innerStack.add(innerType)
			transformed.addAll(transformVariableArray(variable, innerType, innerStack))
		} else if (innerType instanceof RecordTypeDefinition) {
			for (field : innerType.fieldDeclarations) {
				var innerField = new ArrayList<FieldDeclaration>
				innerField.add(field)
				var innerStack = new ArrayList<ArrayTypeDefinition>
				innerStack.addAll(arrayStack)
				transformed.addAll(transformVariableField(variable, innerField, innerStack))
			}
			return transformed
		} else {	// Simple
			transformed.add(createVariableDeclaration => [
				it.name = variable.name
				it.type = variable.type.transformType
				it.expression = variable.expression?.transformExpression.getOnlyElement
			])
			trace.put(variable, transformed.head)
		}
		
		return transformed
	}
	
	private def Expression getExpressionFromRecordLiteral(RecordLiteralExpression initial, List<FieldDeclaration> currentField) {
		for (assignment : initial.fieldAssignments) {
			if (currentField.head.name == assignment.reference) {
				if (currentField.size == 1) {
					return assignment.value
				} else {
					if (assignment.value instanceof RecordLiteralExpression) {
						//System.out.println("CURRFIELD: " + currentField.size )
						var innerField = new ArrayList<FieldDeclaration>
						innerField.addAll(currentField.subList(1, currentField.size))
						return getExpressionFromRecordLiteral(assignment.value as RecordLiteralExpression, innerField)
					} else {
						throw new IllegalArgumentException("Invalid expression!")
					}
				}
			}
		}
	}
	
	private def Type createTransformedRecordType(List<ArrayTypeDefinition> arrayStack, Type innerType) {
		if(arrayStack.size > 0) {
			var stackCopy = new ArrayList<ArrayTypeDefinition>
			stackCopy.addAll(arrayStack)
			var stackTop = stackCopy.remove(0)
			var arrayTypeDef = constraintFactory.createArrayTypeDefinition
			arrayTypeDef.size = stackTop.size.transformExpression.getOnlyElement as IntegerLiteralExpression
			arrayTypeDef.elementType = createTransformedRecordType(stackCopy, innerType)
			return arrayTypeDef
		} else {
			return innerType.transformType
		}
	}
	
		
	protected def TypeDefinition getTypeDefinitionFromType(Type type) {
		// Resolve type reference (may be chain) or return type definition
		if (type instanceof TypeReference) {
			var innerType = (type as TypeReference).reference.type
			return getTypeDefinitionFromType(innerType)
		} else {
			return type as TypeDefinition
		}
	}
	
	protected def List<Pair<VariableDeclaration, List<FieldDeclaration>>> exploreComplexType(VariableDeclaration original, TypeDefinition type, List<FieldDeclaration> currentField) {
		var List<Pair<VariableDeclaration, List<FieldDeclaration>>> result = new ArrayList<Pair<VariableDeclaration, List<FieldDeclaration>>>
		
		if (type instanceof RecordTypeDefinition) {
			// In case of records go into each field
			for (field : type.fieldDeclarations) {
				// Get current field by extending the previous (~current) with the one to explore
				var newCurrent = new ArrayList<FieldDeclaration>
				newCurrent.addAll(currentField)
				newCurrent.add(field)
				//Explore
				result += exploreComplexType(original, getTypeDefinitionFromType(field.type), newCurrent)
			}
		} else if (type instanceof ArrayTypeDefinition) {
			// In case of arrays jump to the inner type
			result += exploreComplexType(original, getTypeDefinitionFromType(type.elementType), currentField)
		} else {	//Simple
			// In case of simple types create a result element
			result += new Pair<VariableDeclaration, List<FieldDeclaration>>(original, currentField)
		}
		
		return result
	}
	
	protected def List<Object> collectAccessList(ReferenceExpression exp) {
		var List<Object> result = new ArrayList<Object>
		if (exp instanceof ArrayAccessExpression) {
			// if possible, add inner
			var inner = exp.operand
			if(inner instanceof ReferenceExpression) {
				result.addAll(collectAccessList(inner))
			}
			// add own
			result.add(exp.arguments.getOnlyElement())
		} else if (exp instanceof RecordAccessExpression) {
			// if possible, add inner
			var inner = exp.operand
			if(inner instanceof ReferenceExpression) {
				result.addAll(collectAccessList(inner))
			}
			// add own
			result.add(exp.field)
		} else if (exp instanceof SelectExpression){
			// if possible, jump over (as it returns a value with the same access list)
			var inner = exp.operand
			if(inner instanceof ReferenceExpression) {
				result.addAll(collectAccessList(inner))
			}
		} else {
			// function access and direct reference signal the end of the chain: let return with empty
		}
		return result
	}
	
	/*protected def Declaration findDeclarationOfReferenceExpression(ReferenceExpression expression) {
		if (expression instance)
	}*/
	
	protected def boolean isSameAccessTree(List<FieldDeclaration> fieldsList, List<String> currentAccessList) {
		if (fieldsList.size < currentAccessList.size) {
			return false
		}
		for (var i = 0; i < currentAccessList.size; i++) {
			if(currentAccessList.get(i) != fieldsList.get(i).name) {
				return false
			}
		}
		return true
	}
	
}
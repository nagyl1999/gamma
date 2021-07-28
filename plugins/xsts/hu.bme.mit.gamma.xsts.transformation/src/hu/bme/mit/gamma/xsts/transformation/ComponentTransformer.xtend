package hu.bme.mit.gamma.xsts.transformation

import hu.bme.mit.gamma.expression.model.DirectReferenceExpression
import hu.bme.mit.gamma.expression.model.Expression
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory
import hu.bme.mit.gamma.expression.model.TypeReference
import hu.bme.mit.gamma.lowlevel.xsts.transformation.LowlevelToXstsTransformer
import hu.bme.mit.gamma.lowlevel.xsts.transformation.TransitionMerging
import hu.bme.mit.gamma.statechart.composite.AbstractSynchronousCompositeComponent
import hu.bme.mit.gamma.statechart.composite.AsynchronousAdapter
import hu.bme.mit.gamma.statechart.composite.CascadeCompositeComponent
import hu.bme.mit.gamma.statechart.composite.ComponentInstance
import hu.bme.mit.gamma.statechart.composite.ControlFunction
import hu.bme.mit.gamma.statechart.interface_.AnyTrigger
import hu.bme.mit.gamma.statechart.interface_.Component
import hu.bme.mit.gamma.statechart.lowlevel.model.Package
import hu.bme.mit.gamma.statechart.lowlevel.transformation.GammaToLowlevelTransformer
import hu.bme.mit.gamma.statechart.statechart.StatechartDefinition
import hu.bme.mit.gamma.statechart.util.StatechartUtil
import hu.bme.mit.gamma.util.GammaEcoreUtil
import hu.bme.mit.gamma.xsts.model.AbstractAssignmentAction
import hu.bme.mit.gamma.xsts.model.Action
import hu.bme.mit.gamma.xsts.model.InEventGroup
import hu.bme.mit.gamma.xsts.model.RegionGroup
import hu.bme.mit.gamma.xsts.model.XSTS
import hu.bme.mit.gamma.xsts.model.XSTSModelFactory
import hu.bme.mit.gamma.xsts.util.XstsActionUtil
import java.util.List
import java.util.logging.Level
import java.util.logging.Logger
import org.eclipse.emf.ecore.util.EcoreUtil

import static com.google.common.base.Preconditions.checkState

import static extension hu.bme.mit.gamma.expression.derivedfeatures.ExpressionModelDerivedFeatures.*
import static extension hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.*
import static extension hu.bme.mit.gamma.xsts.derivedfeatures.XstsDerivedFeatures.*
import static extension hu.bme.mit.gamma.xsts.transformation.util.Namings.*

class ComponentTransformer {
	// This gammaToLowlevelTransformer must be the same during this transformation cycle due to tracing
	protected final GammaToLowlevelTransformer gammaToLowlevelTransformer
	// Transformation settings
	protected final boolean optimize
	protected final boolean useHavocActions
	protected final boolean extractGuards
	protected final TransitionMerging transitionMerging
	// Auxiliary objects
	protected final extension GammaEcoreUtil ecoreUtil = GammaEcoreUtil.INSTANCE
	protected final extension EnvironmentalActionFilter environmentalActionFilter = EnvironmentalActionFilter.INSTANCE
	protected final extension EventConnector eventConnector = EventConnector.INSTANCE
	protected final extension SystemReducer systemReducer = SystemReducer.INSTANCE
	protected final extension ExpressionModelFactory expressionModelFactory = ExpressionModelFactory.eINSTANCE
	protected final extension XSTSModelFactory xStsModelFactory = XSTSModelFactory.eINSTANCE
	protected final extension XstsActionUtil xStsActionUtil = XstsActionUtil.INSTANCE
	protected final extension StatechartUtil statechartUtil = StatechartUtil.INSTANCE
	// Logger
	protected final Logger logger = Logger.getLogger("GammaLogger")
	
	new(GammaToLowlevelTransformer gammaToLowlevelTransformer, boolean optimize,
			boolean useHavocActions, boolean extractGuards,	TransitionMerging transitionMerging) {
		this.gammaToLowlevelTransformer = gammaToLowlevelTransformer
		this.optimize = optimize
		this.useHavocActions = useHavocActions
		this.extractGuards = extractGuards
		this.transitionMerging = transitionMerging
	}
	
	def dispatch XSTS transform(Component component, Package lowlevelPackage) {
		throw new IllegalArgumentException("Not supported component type: " + component)
	}
	
	def dispatch XSTS transform(AsynchronousAdapter component, Package lowlevelPackage) {
		// TODO maybe isTop boolean variables should be introduced as now in event actions are created discarded
		component.checkAdapter
		val wrappedInstance = component.wrappedComponent
		val wrappedType = wrappedInstance.type
		
		val messageQueue = component.messageQueues.head
		
		wrappedType.transformParameters(wrappedInstance.arguments) 
		val xSts = wrappedType.transform(lowlevelPackage)
		
		val inEventAction = xSts.inEventTransition
		// Deleting synchronous event assignments
		val xStsSynchronousInEventVariables = xSts.variableGroups
			.filter[it.annotation instanceof InEventGroup].map[it.variables]
			.flatten // There are more than one
		for (xStsAssignment : inEventAction.getAllContentsOfType(AbstractAssignmentAction)) {
			val xStsDeclaration = (xStsAssignment.lhs as DirectReferenceExpression).declaration
			if (xStsSynchronousInEventVariables.contains(xStsDeclaration)) {
				xStsAssignment.remove // Deleting in-event bool flags
			}
		}
		
		val extension eventRef = new EventReferenceToXstsVariableMapper(xSts)
		// Collecting the referenced event variables
		val xStsReferencedEventVariables = newHashSet
		for (eventReference : messageQueue.eventReference) {
			xStsReferencedEventVariables += eventReference.variables
		}
		
		val newInEventAction = createSequentialAction
		// Setting the referenced event variables to false
		for (xStsEventVariable : xStsReferencedEventVariables) {
			newInEventAction.actions += createAssignmentAction => [
				it.lhs = statechartUtil.createReferenceExpression(xStsEventVariable)
				it.rhs = createFalseExpression
			]
		}
		// Enabling the setting of the referenced event variables to true if no other is set
		for (xStsEventVariable : xStsReferencedEventVariables) {
			val negatedVariables = newArrayList
			negatedVariables += xStsReferencedEventVariables
			negatedVariables -= xStsEventVariable
			val branch = createIfActionBranch(
				xStsActionUtil.connectThroughNegations(negatedVariables),
				createAssignmentAction => [
					it.lhs = statechartUtil.createReferenceExpression(xStsEventVariable)
					it.rhs = createTrueExpression
				]
			)
			branch.extendChoiceWithBranch(createTrueExpression, createEmptyAction)
			newInEventAction.actions += branch
		}
		// Binding event variables that come from the same ports
		newInEventAction.actions += xSts.createEventAssignmentsBoundToTheSameSystemPort(wrappedType)
		 // Original parameter settings
		newInEventAction.actions += inEventAction.action
		// Binding parameter variables that come from the same ports
		newInEventAction.actions += xSts.createParameterAssignmentsBoundToTheSameSystemPort(wrappedType)
		xSts.inEventTransition = newInEventAction.wrap
		
		return xSts
	}
	
	def dispatch XSTS transform(AbstractSynchronousCompositeComponent component, Package lowlevelPackage) {
		logger.log(Level.INFO, "Transforming abstract synchronous composite " + component.name)
		var XSTS xSts = null
		val componentMergedActions = <Component, Action>newHashMap // To handle multiple schedulings in CascadeCompositeComponents
		
		// Input, output and tracing merged actions
		val components = component.components
		for (var i = 0; i < components.size; i++) {
			val subcomponent = components.get(i)
			val componentType = subcomponent.type
			// Normal transformation
			componentType.transformParameters(subcomponent.arguments) // Change the reference from parameters to constants
			val newXSts = componentType.transform(lowlevelPackage)
			newXSts.customizeDeclarationNames(subcomponent)
			if (xSts === null) {
				xSts = newXSts
			}
			else {
				// Adding new elements
				xSts.typeDeclarations += newXSts.typeDeclarations
				xSts.publicTypeDeclarations += newXSts.publicTypeDeclarations
				xSts.variableGroups += newXSts.variableGroups
				xSts.variableDeclarations += newXSts.variableDeclarations
				xSts.transientVariables += newXSts.transientVariables
				xSts.controlVariables += newXSts.controlVariables
				xSts.clockVariables += newXSts.clockVariables
				xSts.constraints += newXSts.constraints
				// Initializing action
				val variableInitAction = createSequentialAction
				variableInitAction.actions += xSts.variableInitializingTransition.action
				variableInitAction.actions += newXSts.variableInitializingTransition.action
				xSts.variableInitializingTransition = variableInitAction.wrap
				val configInitAction = createSequentialAction
				configInitAction.actions += xSts.configurationInitializingTransition.action
				configInitAction.actions += newXSts.configurationInitializingTransition.action
				xSts.configurationInitializingTransition = configInitAction.wrap
				val entryAction = createSequentialAction
				entryAction.actions += xSts.entryEventTransition.action
				entryAction.actions += newXSts.entryEventTransition.action
				xSts.entryEventTransition = entryAction.wrap
			}
			// Merged action
			val actualComponentMergedAction = createSequentialAction => [
				it.actions += newXSts.mergedAction
			]
			// In and Out actions - using sequential actions to make sure they are composite actions
			// Methods reset... and delete... require this
			val newInEventAction = createSequentialAction => [ it.actions += newXSts.inEventTransition.action ]
			newXSts.inEventTransition = newInEventAction.wrap
			val newOutEventAction = createSequentialAction => [ it.actions += newXSts.outEventTransition.action ]
			newXSts.outEventTransition = newOutEventAction.wrap
			// Resetting channel events
			// 1) the Sync ort semantics: Resetting channel IN events AFTER schedule would result in a deadlock
			// 2) the Casc semantics: Resetting channel OUT events BEFORE schedule would delete in events of subsequent components
			// Note, System in and out events are reset in the env action
			if (component instanceof CascadeCompositeComponent) {
				// Resetting IN events AFTER schedule
				val clonedNewInEventAction = newInEventAction.clone
						.resetEverythingExceptPersistentParameters(componentType) // Clone is important
				actualComponentMergedAction.actions += clonedNewInEventAction // Putting the new action AFTER
			}
			else {
				// Resetting OUT events BEFORE schedule
				val clonedNewOutEventAction = newOutEventAction.clone // Clone is important
						.resetEverythingExceptPersistentParameters(componentType)
				actualComponentMergedAction.actions.add(0, clonedNewOutEventAction) // Putting the new action BEFORE
			}
			// In event
			newInEventAction.deleteEverythingExceptSystemEventsAndParameters(component)
			if (xSts !== newXSts) { // Only if this is not the first component
				val inEventAction = createSequentialAction
				inEventAction.actions += xSts.inEventTransition.action
				inEventAction.actions += newInEventAction
				xSts.inEventTransition = inEventAction.wrap
			}
			// Out event
			newOutEventAction.deleteEverythingExceptSystemEventsAndParameters(component)
			if (xSts !== newXSts) { // Only if this is not the first component
				val outEventAction = createSequentialAction
				outEventAction.actions += xSts.outEventTransition.action
				outEventAction.actions += newOutEventAction
				xSts.outEventTransition = outEventAction.wrap
			}
			// Tracing merged action
			componentMergedActions.put(componentType, actualComponentMergedAction.clone)
		}
		
		// Merged action based on scheduling instances
		val scheduledInstances = component.scheduledInstances
		val mergedAction = (component instanceof CascadeCompositeComponent) ? createSequentialAction : createOrthogonalAction
		for (var i = 0; i < scheduledInstances.size; i++) {
			val subcomponent = scheduledInstances.get(i)
			val componentType = subcomponent.type
			if (componentMergedActions.containsKey(componentType)) {
				mergedAction.actions += componentMergedActions.get(componentType).clone
			}
		}
		xSts.changeTransitions(mergedAction.wrap)
		
		xSts.name = component.name
		logger.log(Level.INFO, "Deleting unused instance ports in " + component.name)
		xSts.deleteUnusedPorts(component) // Deleting variable assignments for unused ports
		// Connect only after xSts.mergedTransition.action = mergedAction
		logger.log(Level.INFO, "Connecting events through channels in " + component.name)
		xSts.connectEventsThroughChannels(component) // Event (variable setting) connecting across channels
		logger.log(Level.INFO, "Binding event to system port events in " + component.name)
		val oldInEventAction = xSts.inEventTransition.action
		val bindingAssignments = xSts.createEventAndParameterAssignmentsBoundToTheSameSystemPort(component)
		// Optimization: removing old NonDeterministicActions 
		bindingAssignments.removeNonDeterministicActionsReferencingAssignedVariables(oldInEventAction)
		val newInEventAction = createSequentialAction => [
			it.actions += oldInEventAction
			// Bind together ports connected to the same system port
			it.actions += bindingAssignments
		]
		xSts.inEventTransition = newInEventAction.wrap
		return xSts
	}
	
	def dispatch XSTS transform(StatechartDefinition statechart, Package lowlevelPackage) {
		logger.log(Level.INFO, "Transforming statechart " + statechart.name)
		// Note that the package is already transformed and traced because of the "val lowlevelPackage = gammaToLowlevelTransformer.transform(_package)" call
		val lowlevelStatechart = gammaToLowlevelTransformer.transform(statechart)
		lowlevelPackage.components += lowlevelStatechart
		val lowlevelToXSTSTransformer = new LowlevelToXstsTransformer(
			lowlevelPackage, optimize, useHavocActions, extractGuards, transitionMerging)
		val xStsEntry = lowlevelToXSTSTransformer.execute
		lowlevelPackage.components -= lowlevelStatechart // So that next time the matches do not return elements from this statechart
		val xSts = xStsEntry.key
		// 0-ing all variable declaration initial expression, the normal ones are in the init action
		for (variable : xSts.variableDeclarations) {
			val type = variable.type
			variable.expression = type.defaultExpression
		}
		return xSts
	}
	
	//
	
	private def checkAdapter(AsynchronousAdapter component) {
		val messageQueues = component.messageQueues
		checkState(messageQueues.size == 1)
		// The capacity (and priority) do not matter, as they are from the environment
		checkState(component.clocks.empty)
		val controlSpecifications = component.controlSpecifications
		checkState(controlSpecifications.size == 1)
		val controlSpecification = controlSpecifications.head
		val trigger = controlSpecification.trigger
		checkState(trigger instanceof AnyTrigger)
		val controlFunction = controlSpecification.controlFunction
		checkState(controlFunction == ControlFunction.RUN_ONCE)
	}
		
	private def transformParameters(Component component, List<Expression> arguments) {
		val _package = component.containingPackage
		val parameterDeclarations = newArrayList
		parameterDeclarations += component.parameterDeclarations // So delete does not mess the list up
		// Theta back-annotation retrieves the argument values from the constant list
		for (parameter : parameterDeclarations) {
			val argumentConstant = createConstantDeclaration => [
				it.name = "__" + parameter.name + "Argument__"
				it.type = parameter.type.clone
				it.expression = arguments.get(parameter.index).clone
			]
			_package.constantDeclarations += argumentConstant
			// Changing the references to the constant
			argumentConstant.change(parameter, component)
		}
		// Deleting after the index settings have been completed (otherwise the index always returns 0)
		EcoreUtil.deleteAll(parameterDeclarations, true)
	}
	
	private def void customizeDeclarationNames(XSTS xSts, ComponentInstance instance) {
		val type = instance.derivedType
		if (type instanceof StatechartDefinition) {
			// Customizing every variable name
			for (variable : xSts.variableDeclarations) {
				variable.name = variable.getCustomizedName(instance)
			}
			// Customizing region type declaration name
			for (regionType : xSts.variableGroups.filter[it.annotation instanceof RegionGroup]
					.map[it.variables].flatten.map[it.type].filter(TypeReference).map[it.reference]) {
				regionType.name = regionType.customizeRegionTypeName(type)
			}
		}
	}
	
}
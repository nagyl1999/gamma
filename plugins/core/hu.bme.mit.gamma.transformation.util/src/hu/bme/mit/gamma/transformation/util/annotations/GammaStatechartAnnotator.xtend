package hu.bme.mit.gamma.transformation.util.annotations

import hu.bme.mit.gamma.action.model.ActionModelFactory
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory
import hu.bme.mit.gamma.expression.model.ParameterDeclaration
import hu.bme.mit.gamma.expression.model.VariableDeclaration
import hu.bme.mit.gamma.statechart.composite.SynchronousComponentInstance
import hu.bme.mit.gamma.statechart.interface_.Event
import hu.bme.mit.gamma.statechart.interface_.InterfaceModelFactory
import hu.bme.mit.gamma.statechart.interface_.Package
import hu.bme.mit.gamma.statechart.interface_.Port
import hu.bme.mit.gamma.statechart.statechart.EntryState
import hu.bme.mit.gamma.statechart.statechart.RaiseEventAction
import hu.bme.mit.gamma.statechart.statechart.Region
import hu.bme.mit.gamma.statechart.statechart.State
import hu.bme.mit.gamma.statechart.statechart.StatechartDefinition
import hu.bme.mit.gamma.statechart.statechart.Transition
import hu.bme.mit.gamma.statechart.util.StatechartUtil
import hu.bme.mit.gamma.transformation.util.queries.RaiseInstanceEvents
import java.util.AbstractMap.SimpleEntry
import java.util.Collection
import java.util.List
import java.util.Map
import java.util.Map.Entry
import java.util.Set
import org.eclipse.viatra.query.runtime.api.ViatraQueryEngine
import org.eclipse.viatra.query.runtime.emf.EMFScope
import org.eclipse.xtend.lib.annotations.Data

import static extension hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.*

class GammaStatechartAnnotator {
	protected final Package gammaPackage
	protected final ViatraQueryEngine engine
	// Transition coverage
	protected boolean TRANSITION_COVERAGE
	protected final Set<SynchronousComponentInstance> transitionCoverableComponents = newHashSet
	protected final Set<Transition> coverableTransitions = newHashSet
	protected final Map<Transition, VariableDeclaration> transitionVariables = newHashMap // Boolean variables
	// Transition pair coverage (same as the normal transition coverage, the difference is that the values are reused in pairs)
	protected boolean TRANSITION_PAIR_COVERAGE
	protected final Set<SynchronousComponentInstance> transitionPairCoverableComponents = newHashSet
	protected final Set<Transition> coverableTransitionPairs = newHashSet
	protected long transitionId = 1 // As 0 is the reset value
	protected final Map<Transition, Long> transitionIds = newHashMap
	protected final Map<State, VariablePair> transitionPairVariables = newHashMap
	protected final List<TransitionPairAnnotation> transitionPairAnnotations = newArrayList
	// Interaction coverage
	protected boolean INTERACTION_COVERAGE
	protected boolean RECEIVER_CONSIDERATION
	protected final Set<Port> interactionCoverablePorts= newHashSet
	protected final Set<ParameterDeclaration> newEventParameters = newHashSet
	protected long senderId = 1 // As 0 is the reset value
	protected long recevierId = 1 // As 0 is the reset value
	protected final Map<RaiseEventAction, Long> sendingIds = newHashMap
	protected final Map<Transition, Long> receivingIds = newHashMap
	protected final Map<Transition, List<Entry<Port, Event>>> receivingInteractions = newHashMap // Check: list must be unique
	protected final Map<Region, List<VariablePair>> regionInteractionVariables = newHashMap // Check: list must be unique
	protected final Map<StatechartDefinition, // Optimization: stores the variable pairs of other regions for reuse
		List<VariablePair>> statechartInteractionVariables = newHashMap // Check: list must be unique
	protected final List<Interaction> interactions = newArrayList
	// Resettable variables
	protected final Set<VariableDeclaration> resetableVariables = newHashSet
	// Factories
	protected final extension ExpressionModelFactory expressionModelFactory = ExpressionModelFactory.eINSTANCE
	protected final extension ActionModelFactory actionModelFactory = ActionModelFactory.eINSTANCE
	protected final extension InterfaceModelFactory interfaceModelFactory = InterfaceModelFactory.eINSTANCE
	protected final extension StatechartUtil statechartUtil = StatechartUtil.INSTANCE
	// Namings
	protected final AnnotationNamings annotationNamings = new AnnotationNamings // Instance due to the id
	
	new(Package gammaPackage,
			Collection<SynchronousComponentInstance> transitionCoverableComponents,
			Collection<SynchronousComponentInstance> transitionPairCoverableComponents,
			Collection<Port> interactionCoverablePorts) {
		this.gammaPackage = gammaPackage
		this.engine = ViatraQueryEngine.on(new EMFScope(gammaPackage.eResource.resourceSet))
		if (!transitionCoverableComponents.empty) {
			this.TRANSITION_COVERAGE = true
			this.transitionCoverableComponents += transitionCoverableComponents
			this.coverableTransitions += transitionCoverableComponents
				.map[it.type].filter(StatechartDefinition)
				.map[it.transitions].flatten
		}
		if (!transitionPairCoverableComponents.empty) {
			this.TRANSITION_PAIR_COVERAGE = true
			this.transitionPairCoverableComponents += transitionPairCoverableComponents
			this.coverableTransitionPairs += transitionPairCoverableComponents
				.map[it.type].filter(StatechartDefinition)
				.map[it.transitions].flatten
		}
		if (!interactionCoverablePorts.isEmpty) {
			this.INTERACTION_COVERAGE = true
			this.RECEIVER_CONSIDERATION = true
			this.interactionCoverablePorts += interactionCoverablePorts
		}
	}
	
	// Transition coverage
	
	protected def needsAnnotation(Transition transition) {
		return !(transition.sourceState instanceof EntryState)
	}
	
	protected def createTransitionVariable(Transition transition,
			Map<Transition, VariableDeclaration> variables, boolean isResetable) {
		val statechart = transition.containingStatechart
		val variable = createVariableDeclaration => [
			it.type = createBooleanTypeDefinition
			it.name = annotationNamings.getVariableName(transition)
		]
		statechart.variableDeclarations += variable
		variables.put(transition, variable)
		if (isResetable) {
			variable.addToResetableVariables
		}
		return variable
	}

	//
	
	def annotateModelForTransitionCoverage() {
		if (!TRANSITION_COVERAGE) {
			return
		}
		for (transition : coverableTransitions.filter[it.needsAnnotation]) {
			val variable = transition.createTransitionVariable(transitionVariables, true)
			transition.effects += variable.createAssignment(createTrueExpression)
		}
	}
	
	def getTransitionVariables() {
		return new TransitionAnnotations(this.transitionVariables)
	}
	
	// Transition pair coverage
	
	protected def isIncomingTransition(Transition transition) {
		return transition.targetState instanceof State
	}
	
	protected def isOutgoingTransition(Transition transition) {
		return transition.sourceState instanceof State
	}
	
	protected def getTransitionId(Transition transition) {
		if (!transitionIds.containsKey(transition)) {
			transitionIds.put(transition, transitionId++)
		}
		return transitionIds.get(transition)
	}
	
	protected def getOrCreateVariablePair(State state) {
		// Now every time a new variable pair is created, this could be optimized later
		// e.g., states, that are not reachable from each other, could use the same variable pair
		if (!transitionPairVariables.containsKey(state)) {
			val statechart = state.containingStatechart
			val variablePair = statechart.createVariablePair(null, null,
				false /*They are not resettable, as two cycles have to be considered*/)
			transitionPairVariables.put(state, variablePair)
		}
		return transitionPairVariables.get(state)
	}
	
	def annotateModelForTransitionPairCoverage() {
		if (!TRANSITION_PAIR_COVERAGE) {
			return
		}
		val incomingTransitions = coverableTransitionPairs.filter[it.incomingTransition]
		val outgoingTransitions = coverableTransitionPairs.filter[it.outgoingTransition]
		val incomingTransitionAnnotations = newArrayList
		val outgoingTransitionAnnotations = newArrayList
		// States with incoming and outgoing transitions
		val states = incomingTransitions.map[it.targetState].filter(State).toSet
		states.retainAll(outgoingTransitions.map[it.sourceState].toList)
		for (state : states) {
			val variablePair = state.getOrCreateVariablePair
			val firstVariable = variablePair.first
			val secondVariable = variablePair.second
			state.exitActions += secondVariable.createAssignment(firstVariable.createReferenceExpression)
		}
		for (incomingTransition : incomingTransitions) {
			val incomingId =  incomingTransition.transitionId
			val state = incomingTransition.targetState as State
			val variablePair = state.getOrCreateVariablePair
			val firstVariable = variablePair.first
			val secondVariable = variablePair.second
			incomingTransition.effects += firstVariable.createAssignment(incomingId.toIntegerLiteral) /*FirstVariable*/
			incomingTransitionAnnotations += new TransitionAnnotation(incomingTransition,
				secondVariable /*SecondVariable, as the exit action in the state will shift it here*/, incomingId)
		}
		for (outgoingTransition : outgoingTransitions) {
			val outgoingId =  outgoingTransition.transitionId
			val state = outgoingTransition.sourceState as State
			val variablePair = state.getOrCreateVariablePair
			val firstVariable = variablePair.first
			outgoingTransition.effects += firstVariable.createAssignment(outgoingId.toIntegerLiteral)
			outgoingTransitionAnnotations += new TransitionAnnotation(outgoingTransition,
				firstVariable, outgoingId)
		}
		for (incomingTransitionAnnotation : incomingTransitionAnnotations) {
			val incomingTransition = incomingTransitionAnnotation.getTransition
			val state = incomingTransition.targetState as State
			for (outgoingTransitionAnnotation : outgoingTransitionAnnotations
					.filter[it.transition.sourceState === state]) {
				// Annotation objects are NOT cloned
				transitionPairAnnotations += new TransitionPairAnnotation(
					incomingTransitionAnnotation, outgoingTransitionAnnotation)
			}
		}
	}
	
	def getTransitionPairAnnotations() {
		return transitionPairAnnotations
	}
	
	// Interaction coverage
	
	protected def hasSendingId(RaiseEventAction action) {
		return sendingIds.containsKey(action)
	}
	
	protected def getSendingId(RaiseEventAction action) {
		if (!sendingIds.containsKey(action)) {
			sendingIds.put(action, senderId++)
		}
		return sendingIds.get(action)
	}
	
	protected def getReceivingId(Transition transition) {
		if (!receivingIds.containsKey(transition)) {
			receivingIds.put(transition, recevierId++)
		}
		return receivingIds.get(transition)
	}
	
	protected def getInteractionVariables(Region region) {
		if (!regionInteractionVariables.containsKey(region)) {
			regionInteractionVariables.put(region, newArrayList)
		}
		return regionInteractionVariables.get(region)
	}
	
	protected def getInteractionVariables(StatechartDefinition statechart) {
		if (!statechartInteractionVariables.containsKey(statechart)) {
			statechartInteractionVariables.put(statechart, newArrayList)
		}
		return statechartInteractionVariables.get(statechart)
	}
	
	protected def getReceivingInteractions(Transition transition) {
		if (!receivingInteractions.containsKey(transition)) {
			receivingInteractions.put(transition, newArrayList)
		}
		return receivingInteractions.get(transition)
	}
	
	protected def putReceivingInteraction(Transition transition, Port port, Event event) {
		val interactions = transition.receivingInteractions
		interactions += new SimpleEntry(port, event)
	}
	
	protected def hasReceivingInteraction(Transition transition, Port port, Event event) {
		val receivingInteractionsOfTransition = transition.receivingInteractions
		return receivingInteractionsOfTransition.contains(new SimpleEntry(port, event))
	}
	
	protected def isThereEnoughInteractionVariable(Transition transition) {
		val region = transition.correspondingRegion
		val interactionVariablesList = region.interactionVariables
		val receivingInteractionsList = transition.receivingInteractions
		return receivingInteractionsList.size <= interactionVariablesList.size
	}
	
	protected def getCorrespondingRegion(Transition transition) {
		return transition.sourceState.parentRegion
	}
	
	protected def getOrCreateInteractionVariablePair(Transition transition) {
		val region = transition.correspondingRegion
		val statechart = region.containingStatechart
		val regionInteractionVariables = region.interactionVariables
		val statechartInteractionVariables = statechart.interactionVariables
		return region.getOrCreateVariablePair(regionInteractionVariables,
			statechartInteractionVariables, true)
	}
	
	protected def getInteractionVariables(Transition transition, Port port, Event event) {
		if (!transition.isThereEnoughInteractionVariable) {
			transition.getOrCreateInteractionVariablePair
		}
		val interactions = transition.receivingInteractions
		// The i. interaction is saved using the i. variable
		val index = interactions.indexOf(new SimpleEntry(port, event))
		val region = transition.correspondingRegion
		val regionVariables = region.interactionVariables
		return regionVariables.get(index)
	}
	
	def annotateModelForInteractionCoverage() {
		if (!INTERACTION_COVERAGE) {
			return
		}
		val interactionMatcher = RaiseInstanceEvents.Matcher.on(engine)
		val matches = interactionMatcher.allMatches
		val relevantMatches = matches
				.filter[ // If BOTH ports are included, the interaction is covered
					interactionCoverablePorts.contains(it.outPort) &&
						interactionCoverablePorts.contains(it.inPort)]
		
		val raisedEvents = relevantMatches.map[it.raisedEvent].toSet // Set, so one event is set only once
		// Creating event parameters
		for (event : raisedEvents) {
			val newParameter = createParameterDeclaration => [
				it.type = createIntegerTypeDefinition
				it.name = annotationNamings.getParameterName(event)
			]
			event.parameterDeclarations += newParameter
			newEventParameters += newParameter
		}
		
		// Annotating raise event actions and transitions
		for (match : relevantMatches) {
			// Sending
			val raiseEventAction = match.raiseEventAction
			if (!raiseEventAction.hasSendingId) {
				// One raise event action can synchronize to multiple transitions (broadcast channel)
				val sendingId = raiseEventAction.sendingId // Must not be retrieved before the enclosing If
				raiseEventAction.arguments += sendingId.toIntegerLiteral
			}
			// Receiving
			val inPort = match.inPort
			val event = match.raisedEvent
			val inParameter = event.parameterDeclarations.last // It is always the last
			val receivingTransition = match.receivingTransition
			
			// We do not want to duplicate the same assignments to the same variable
			if (!receivingTransition.hasReceivingInteraction(inPort, event)) {
				receivingTransition.putReceivingInteraction(inPort, event)

				val interactionVariables = receivingTransition.getInteractionVariables(
						inPort, event)
				val senderVariable = interactionVariables.first
				// Sender assignment, necessary even when receiver is not
				receivingTransition.effects += senderVariable.createAssignment(
					createEventParameterReferenceExpression => [
						it.port = inPort
						it.event = event
						it.parameter = inParameter
					]
				)
				if (RECEIVER_CONSIDERATION) {
					val receivingId = receivingTransition.receivingId
					val receiverVariable = interactionVariables.second
					// Receiver assignment
					receivingTransition.effects += receiverVariable.createAssignment(
						receivingId.toIntegerLiteral)
				}
			}
			val variablePair = receivingTransition.getInteractionVariables(inPort, event)
			interactions += new Interaction(raiseEventAction, receivingTransition,
				variablePair, raiseEventAction.sendingId, receivingTransition.receivingId)
		}
	}
	
	// Variable pair creators, used both by transition pair and interaction annotation
	
	protected def getOrCreateVariablePair(Region region,
			List<VariablePair> localPool, List<VariablePair> globalPool, boolean resettable) {
		val statechart = region.containingStatechart
		if (region.orthogonal) {
			// A new variable is needed for orthogonal regions and it cannot be shared
			return statechart.createVariablePair(localPool,
				null /*Variables cannot be shared with other regions*/,
				resettable)
		}
		// Optimization, maybe a new one does not need to be created
		return statechart.getOrCreateVariablePair(localPool, globalPool, resettable)
	}
	
	protected def getOrCreateVariablePair(StatechartDefinition statechart,
			List<VariablePair> localPool, List<VariablePair> globalPool, boolean resettable) {
		val localPoolSize = localPool.size
		val globalPoolSize = globalPool.size
		if (localPoolSize < globalPoolSize) {
			// Putting a variable to the local pool from the global pool
			val retrievedVariablePair = globalPool.get(localPoolSize)
			localPool += retrievedVariablePair
			return retrievedVariablePair
		}
		else {
			return statechart.createVariablePair(localPool,
				globalPool /*Variables can be shared with other regions*/,
				resettable)
		}
	}
	
	protected def createVariablePair(StatechartDefinition statechart,
			List<VariablePair> localPool, List<VariablePair> globalPool, boolean resettable) {
		val senderVariable = createVariableDeclaration => [
			it.type = createIntegerTypeDefinition
			it.name = annotationNamings.getFirstVariableName(statechart)
		]
		statechart.variableDeclarations += senderVariable
		var VariableDeclaration receiverVariable = null
		if (RECEIVER_CONSIDERATION) {
			receiverVariable = createVariableDeclaration => [
				it.type = createIntegerTypeDefinition
				it.name = annotationNamings.getSecondVariableName(statechart)
			]
			statechart.variableDeclarations += receiverVariable
		}
		val variablePair = new VariablePair(senderVariable, receiverVariable)
		
		if (localPool !== null) {
			localPool += variablePair
		}
		if (globalPool !== null) {
			globalPool += variablePair
		}
		if (resettable) {
			senderVariable.addToResetableVariables
			receiverVariable.addToResetableVariables
		}
		return variablePair
	}
	
	// Adder
	
	def addToResetableVariables(VariableDeclaration variable) {
		if (variable !== null) {
			resetableVariables += variable
		}
	}
	
	// Getters
	
	def getNewEventParameters() {
		return this.newEventParameters
	}
	
	def getInteractions() {
		return new InteractionAnnotations(this.interactions)
	}
	
	def getResetableVariables() {
		return this.resetableVariables
	}
	
	// Entry point
	
	def annotateModel() {
		annotateModelForTransitionCoverage
		annotateModelForTransitionPairCoverage
		annotateModelForInteractionCoverage
	}
	
	// Auxiliary classes for the transition and interaction
	
	static class TransitionAnnotations {
		
		final Map<Transition, VariableDeclaration> transitionPairVariables
		
		new(Map<Transition, VariableDeclaration> transitionPairVariables) {
			this.transitionPairVariables = transitionPairVariables
		}
		
		def getTransitions() {
			return transitionPairVariables.keySet
		}
		
		def isAnnotated(Transition transition) {
			return transitionPairVariables.containsKey(transition)
		}
		
		def getVariable(Transition transition) {
			return transitionPairVariables.get(transition)
		}
		
		def isEmpty() {
			return transitionPairVariables.empty
		}
		
	}
	
	@Data
	static class VariablePair {
		VariableDeclaration first
		VariableDeclaration second
		
		def hasFirst() {
			return first !== null
		}
		
		def hasSecond() {
			return second !== null
		}
		
	}
	
	@Data
	static class TransitionAnnotation {
		Transition transition
		VariableDeclaration transitionVariable
		Long transitionId
	}
	
	@Data
	static class TransitionPairAnnotation {
		TransitionAnnotation incomingAnnotation
		TransitionAnnotation outgoingAnnotation
	}
	
	@Data
	static class Interaction {
		RaiseEventAction sender
		Transition receiver
		VariablePair variablePair
		Long senderId
		Long receiverId
	}
	
	static class InteractionAnnotations {
		
		final Collection<Interaction> interactions
		Set<Interaction> interactionSet
		
		new(Collection<Interaction> interactions) {
			this.interactions = interactions
		}
		
		def getInteractions() {
			return this.interactions
		}
		
		def getUniqueInteractions() {
			if (interactionSet === null) {
				interactionSet = newHashSet
				// If the interaction has no second variable, duplication can occur
				for (i : interactions) {
					val sender = i.sender
					var Transition receiver = null
					val variablePair = i.variablePair
					val senderId = i.senderId
					var Long receiverId = null
					if (variablePair.hasSecond) {
						receiver = i.receiver
						receiverId = i.receiverId
					}
					interactionSet += new Interaction(sender, receiver, variablePair, senderId, receiverId)
				}
			}
			return interactionSet
		}
		
		def isEmpty() {
			return this.interactions.empty
		}
		
	}
	
}

class AnnotationNamings {
	
	public static val PREFIX = "__id_"
	public static val POSTFIX = "__"
	
	int id = 0
	
	def String getVariableName(Transition transition) '''�IF transition.id !== null��transition.id��ELSE��PREFIX��transition.sourceState.name�_�id++�_�transition.targetState.name��POSTFIX��ENDIF�'''
	def String getFirstVariableName(StatechartDefinition statechart) '''�PREFIX�first_�statechart.name��id++��POSTFIX�'''
	def String getSecondVariableName(StatechartDefinition statechart) '''�PREFIX�second_�statechart.name��id++��POSTFIX�'''
	def String getParameterName(Event event) '''�PREFIX��event.name��POSTFIX�'''
	
}
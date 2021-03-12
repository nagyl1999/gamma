package hu.bme.mit.gamma.genmodel.util;

import java.io.File;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.EcoreUtil2;
import org.eclipse.xtext.xbase.lib.CollectionLiterals;
import org.yakindu.base.types.Direction;
import org.yakindu.base.types.Event;
import org.yakindu.sct.model.sgraph.Scope;
import org.yakindu.sct.model.sgraph.Statechart;
import org.yakindu.sct.model.stext.stext.InterfaceScope;

import hu.bme.mit.gamma.expression.model.BooleanTypeDefinition;
import hu.bme.mit.gamma.expression.model.DecimalTypeDefinition;
import hu.bme.mit.gamma.expression.model.Expression;
import hu.bme.mit.gamma.expression.model.ExpressionModelPackage;
import hu.bme.mit.gamma.expression.model.IntegerTypeDefinition;
import hu.bme.mit.gamma.expression.model.ParameterDeclaration;
import hu.bme.mit.gamma.expression.model.Type;
import hu.bme.mit.gamma.expression.util.ExpressionModelValidator;
import hu.bme.mit.gamma.expression.util.ExpressionType;
import hu.bme.mit.gamma.genmodel.model.AdaptiveContractTestGeneration;
import hu.bme.mit.gamma.genmodel.model.AnalysisLanguage;
import hu.bme.mit.gamma.genmodel.model.AnalysisModelTransformation;
import hu.bme.mit.gamma.genmodel.model.AsynchronousInstanceConstraint;
import hu.bme.mit.gamma.genmodel.model.CodeGeneration;
import hu.bme.mit.gamma.genmodel.model.ComponentReference;
import hu.bme.mit.gamma.genmodel.model.Constraint;
import hu.bme.mit.gamma.genmodel.model.Coverage;
import hu.bme.mit.gamma.genmodel.model.EventMapping;
import hu.bme.mit.gamma.genmodel.model.EventPriorityTransformation;
import hu.bme.mit.gamma.genmodel.model.GenModel;
import hu.bme.mit.gamma.genmodel.model.GenmodelModelPackage;
import hu.bme.mit.gamma.genmodel.model.InterfaceCompilation;
import hu.bme.mit.gamma.genmodel.model.InterfaceMapping;
import hu.bme.mit.gamma.genmodel.model.ModelReference;
import hu.bme.mit.gamma.genmodel.model.OrchestratingConstraint;
import hu.bme.mit.gamma.genmodel.model.PhaseStatechartGeneration;
import hu.bme.mit.gamma.genmodel.model.SchedulingConstraint;
import hu.bme.mit.gamma.genmodel.model.StateCoverage;
import hu.bme.mit.gamma.genmodel.model.StatechartCompilation;
import hu.bme.mit.gamma.genmodel.model.Task;
import hu.bme.mit.gamma.genmodel.model.TestGeneration;
import hu.bme.mit.gamma.genmodel.model.TestReplayModelGeneration;
import hu.bme.mit.gamma.genmodel.model.TransitionCoverage;
import hu.bme.mit.gamma.genmodel.model.Verification;
import hu.bme.mit.gamma.genmodel.model.XSTSReference;
import hu.bme.mit.gamma.genmodel.model.YakinduCompilation;
import hu.bme.mit.gamma.property.model.PropertyPackage;
import hu.bme.mit.gamma.statechart.composite.AsynchronousAdapter;
import hu.bme.mit.gamma.statechart.composite.AsynchronousComponent;
import hu.bme.mit.gamma.statechart.composite.AsynchronousCompositeComponent;
import hu.bme.mit.gamma.statechart.composite.ComponentInstance;
import hu.bme.mit.gamma.statechart.composite.ComponentInstanceReference;
import hu.bme.mit.gamma.statechart.composite.CompositeModelPackage;
import hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures;
import hu.bme.mit.gamma.statechart.interface_.Component;
import hu.bme.mit.gamma.statechart.interface_.EventDeclaration;
import hu.bme.mit.gamma.statechart.interface_.EventDirection;
import hu.bme.mit.gamma.statechart.interface_.InterfaceModelPackage;
import hu.bme.mit.gamma.statechart.interface_.Package;
import hu.bme.mit.gamma.statechart.interface_.RealizationMode;
import hu.bme.mit.gamma.statechart.interface_.TimeSpecification;
import hu.bme.mit.gamma.statechart.util.StatechartUtil;
import hu.bme.mit.gamma.trace.model.ExecutionTrace;
import hu.bme.mit.gamma.util.FileUtil;

public class GenmodelValidator extends ExpressionModelValidator {
	// Singleton
	public static final GenmodelValidator INSTANCE = new GenmodelValidator();
	protected GenmodelValidator() {}
	//
	
	protected final StatechartUtil statechartUtil = StatechartUtil.INSTANCE;
	protected final FileUtil fileUtil = FileUtil.INSTANCE;
	
	// Checking tasks, only one parameter is acceptable
	
	public Collection<ValidationResultMessage> checkTasks(Task task) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (task.getFileName().size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one file name can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.TASK__FILE_NAME, null)));
		}
		if (task.getTargetFolder().size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one target folder can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.TASK__TARGET_FOLDER, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTasks(YakinduCompilation yakinduCompilation) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (yakinduCompilation.getPackageName().size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one package name can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.YAKINDU_COMPILATION__PACKAGE_NAME, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTasks(StatechartCompilation statechartCompilation) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (statechartCompilation.getStatechartName().size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one statechart name can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.STATECHART_COMPILATION__STATECHART_NAME, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTasks(AnalysisModelTransformation analysisModelTransformation) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (analysisModelTransformation.getScheduler().size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one scheduler type can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ANALYSIS_MODEL_TRANSFORMATION__SCHEDULER, null)));
		}
		List<AnalysisLanguage> languages = analysisModelTransformation.getLanguages();
		if (languages.size() != languages.stream().collect(Collectors.toSet()).size()) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single formal language can be specified only once.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ANALYSIS_MODEL_TRANSFORMATION__LANGUAGES, null)));
		}
		ModelReference modelReference = analysisModelTransformation.getModel();
		if (modelReference instanceof XSTSReference) {
			if (languages.stream().anyMatch(it -> it != AnalysisLanguage.UPPAAL)) {
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						"XSTS models can be transformed only to UPPAAL",
						new ReferenceInfo(GenmodelModelPackage.Literals.ANALYSIS_MODEL_TRANSFORMATION__LANGUAGES, null)));
			}
		}
		if (analysisModelTransformation.getCoverages().stream().filter(it -> it instanceof TransitionCoverage).count() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single transition coverage task can be defined.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ANALYSIS_MODEL_TRANSFORMATION__COVERAGES, null)));
		}
		if (analysisModelTransformation.getCoverages().stream().filter(it -> it instanceof StateCoverage).count() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single state coverage task can be defined.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ANALYSIS_MODEL_TRANSFORMATION__COVERAGES, null)));
		}
		Constraint constraint = analysisModelTransformation.getConstraint();
		if (constraint != null) {
			if (modelReference instanceof ComponentReference) {
				ComponentReference componentReference = (ComponentReference)modelReference;
				Component component = componentReference.getComponent();
				if (component instanceof AsynchronousComponent && constraint instanceof OrchestratingConstraint) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"Asynchronous component constraints must contain either a 'top' keyword or references to the contained instances.",
							new ReferenceInfo(GenmodelModelPackage.Literals.ANALYSIS_MODEL_TRANSFORMATION__CONSTRAINT, null)));
				}
			}
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTasks(Verification verification) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		List<AnalysisLanguage> languages = verification.getLanguages();
		if (languages.size() != 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single formal language must be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.VERIFICATION__LANGUAGES, null)));
		}
		File resourceFile = ecoreUtil.getFile(verification.eResource());
		List<String> modelFiles = verification.getFileName();
		if (modelFiles.size() != 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single model file must be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.TASK__FILE_NAME, null)));
		}
		for (String modelFile : modelFiles) {
			if (!fileUtil.isValidRelativeFile(resourceFile, modelFile)) {
				int index = modelFiles.indexOf(modelFile);
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						"This is not a valid relative path to a model file: " + modelFile,
						new ReferenceInfo(GenmodelModelPackage.Literals.TASK__FILE_NAME, index)));
			}
		}
		List<String> queryFiles = verification.getQueryFiles();
		List<PropertyPackage> propertyPackages = verification.getPropertyPackages();
		if (queryFiles.size() + propertyPackages.size() < 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At least one query file must be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.VERIFICATION__QUERY_FILES, null)));
		}
		for (String queryFile : queryFiles) {
			if (!fileUtil.isValidRelativeFile(resourceFile, queryFile)) {
				int index = queryFiles.indexOf(queryFile);
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						"This is not a valid relative path to a query file: " + queryFile,
						new ReferenceInfo(GenmodelModelPackage.Literals.VERIFICATION__QUERY_FILES, index)));
			}
		}
		List<String> testFolders = verification.getTestFolder();
		if (testFolders.size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one test folder can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.VERIFICATION__TEST_FOLDER, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTasks(TestReplayModelGeneration modelGeneration) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		List<String> systemFileNames = modelGeneration.getFileName();
		if (systemFileNames.size() != 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single system file name must be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.TASK__FILE_NAME, null)));
		}
		List<String> targetFolders = modelGeneration.getTargetFolder();
		if (targetFolders.size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one test folder can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.TASK__TARGET_FOLDER, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTimeSpecification(TimeSpecification timeSpecification) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (!typeDeterminator.isInteger(timeSpecification.getValue())) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"Time values must be of type integer.",
					new ReferenceInfo(InterfaceModelPackage.Literals.TIME_SPECIFICATION__VALUE, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkConstraint(AsynchronousInstanceConstraint constraint) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		AnalysisModelTransformation analysisModelTransformation = EcoreUtil2.getContainerOfType(constraint, AnalysisModelTransformation.class);
		ModelReference modelReference = analysisModelTransformation.getModel();
		if (modelReference instanceof ComponentReference) {
			ComponentReference componentReference = (ComponentReference)modelReference;
			Component component = componentReference.getComponent();
			if (!hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.isAsynchronous(component)) {
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						"Asynchronous component constraints must refer to an asynchronous component.",
						new ReferenceInfo(GenmodelModelPackage.Literals.ASYNCHRONOUS_INSTANCE_CONSTRAINT__ORCHESTRATING_CONSTRAINT, null)));
				return validationResultMessages;
			}
			SchedulingConstraint scheduling = EcoreUtil2.getContainerOfType(constraint, SchedulingConstraint.class);
			ComponentInstanceReference instance = constraint.getInstance();
			if (instance != null) {
				ComponentInstance lastInstance = instance.getComponentInstanceHierarchy().get(instance.getComponentInstanceHierarchy().size() - 1);
				if (!hu.bme.mit.gamma.statechart.derivedfeatures.StatechartModelDerivedFeatures.isAsynchronous(lastInstance)) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"Asynchronous component constraints must contain a reference to a contained asynchronous instance.",
							new ReferenceInfo(GenmodelModelPackage.Literals.ASYNCHRONOUS_INSTANCE_CONSTRAINT__INSTANCE, null)));
				}
			}
			if (component instanceof AsynchronousCompositeComponent) {
				if (instance == null) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"Asynchronous component constraints must contain a reference to a contained instance.",
							new ReferenceInfo(GenmodelModelPackage.Literals.ASYNCHRONOUS_INSTANCE_CONSTRAINT__INSTANCE, null)));
				}
				if (scheduling.getInstanceConstraint().stream().filter(it -> ecoreUtil.helperEquals(it.getInstance(), instance)).count() > 1) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"The scheduling constraints for a certain asynchronous component can be defined at most once.",
							new ReferenceInfo(GenmodelModelPackage.Literals.ASYNCHRONOUS_INSTANCE_CONSTRAINT__INSTANCE, null)));
				}
			}
			if (component instanceof AsynchronousAdapter) {
				if (scheduling.getInstanceConstraint().size() > 1) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"Asynchronous adapters can contain at most one constraint.",
							new ReferenceInfo(GenmodelModelPackage.Literals.ASYNCHRONOUS_INSTANCE_CONSTRAINT__ORCHESTRATING_CONSTRAINT, null)));
				}
			}
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkMinimumMaximumOrchestrationPeriodValues(OrchestratingConstraint orchestratingConstraint) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		try {
			TimeSpecification minimum = orchestratingConstraint.getMinimumPeriod();
			TimeSpecification maximum = orchestratingConstraint.getMaximumPeriod();
			if (minimum != null) {
				if (maximum != null) {
					int minimumIntegerValue = statechartUtil.evaluateMilliseconds(minimum);
					int maximumIntegerValue = statechartUtil.evaluateMilliseconds(maximum);
					if (minimumIntegerValue < 0) {
						validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
								"Time value must be positive.",
								new ReferenceInfo(GenmodelModelPackage.Literals.ORCHESTRATING_CONSTRAINT__MINIMUM_PERIOD, null)));
					}
					if (maximumIntegerValue < 0) {
						validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
								"Time value must be positive.",
								new ReferenceInfo(GenmodelModelPackage.Literals.ORCHESTRATING_CONSTRAINT__MAXIMUM_PERIOD, null)));
					}
					if (maximumIntegerValue < minimumIntegerValue) {
						validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
								"The minimum orchestrating period value must be greater than the maximum orchestrating period value.",
								new ReferenceInfo(GenmodelModelPackage.Literals.ORCHESTRATING_CONSTRAINT__MINIMUM_PERIOD, null)));
					}
				}
			}
		} catch (IllegalArgumentException e) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"Both the minimum and maximum values must be of type integer.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ORCHESTRATING_CONSTRAINT__MINIMUM_PERIOD, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTasks(CodeGeneration codeGeneration) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (codeGeneration.getPackageName().size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one package name can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ABSTRACT_CODE_GENERATION__PACKAGE_NAME, null)));
		}
		if (codeGeneration.getLanguage().size() != 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single programming language must be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ABSTRACT_CODE_GENERATION__PACKAGE_NAME, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTasks(TestGeneration testGeneration) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (testGeneration.getPackageName().size() > 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"At most one package name can be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ABSTRACT_CODE_GENERATION__PACKAGE_NAME, null)));
		}
		if (testGeneration.getLanguage().size() != 1) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"A single programming language must be specified.",
					new ReferenceInfo(GenmodelModelPackage.Literals.ABSTRACT_CODE_GENERATION__PACKAGE_NAME, null)));
		}
		return validationResultMessages;
	}
	
	// Additional validation rules
	
	public Collection<ValidationResultMessage> checkGammaImports(GenModel genmodel) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		Set<Package> packageImports = genmodel.getPackageImports().stream().collect(Collectors.toSet());
		for (CodeGeneration codeGenerationTask : javaUtil.filter(genmodel.getTasks(),CodeGeneration.class)) {
			Package parentPackage = StatechartModelDerivedFeatures.getContainingPackage(codeGenerationTask.getComponent());
			packageImports.remove(parentPackage);
		}
		for (AnalysisModelTransformation analysisModelTransformationTask : javaUtil.filter(genmodel.getTasks(), AnalysisModelTransformation.class)) {
			ModelReference modelReference = analysisModelTransformationTask.getModel();
			if (modelReference instanceof ComponentReference) {
				ComponentReference componentReference = (ComponentReference)modelReference;
				Component component = componentReference.getComponent();
				Package parentPackage = StatechartModelDerivedFeatures.getContainingPackage(component);
				packageImports.remove(parentPackage);
			}
			for (Coverage coverage : analysisModelTransformationTask.getCoverages()) {
				List<ComponentInstanceReference> allCoverages = new ArrayList<ComponentInstanceReference>();
				allCoverages.addAll(coverage.getInclude());
				allCoverages.addAll(coverage.getExclude());
				for (ComponentInstanceReference instance : allCoverages) {
					Package instanceParentPackage = StatechartModelDerivedFeatures.getContainingPackage(instance);
					packageImports.remove(instanceParentPackage);
				}
			}
		}
		for (StatechartCompilation statechartCompilationTask : javaUtil.filter(genmodel.getTasks(), StatechartCompilation.class)) {
			for (InterfaceMapping interfaceMapping : statechartCompilationTask.getInterfaceMappings()) {
				Package parentPackage = StatechartModelDerivedFeatures.getContainingPackage(interfaceMapping.getGammaInterface());
				packageImports.remove(parentPackage);
			}
		}
		for (EventPriorityTransformation eventPriorityTransformationTask : javaUtil.filter(genmodel.getTasks(), EventPriorityTransformation.class)) {
			Package parentPackage = StatechartModelDerivedFeatures.getContainingPackage(eventPriorityTransformationTask.getStatechart());
			packageImports.remove(parentPackage);
		}
		for (AdaptiveContractTestGeneration adaptiveContractTestGenerationTask : javaUtil.filter(genmodel.getTasks(), AdaptiveContractTestGeneration.class)) {
			Package parentPackage = StatechartModelDerivedFeatures.getContainingPackage(adaptiveContractTestGenerationTask.getStatechartContract());
			packageImports.remove(parentPackage);
		}
		for (PhaseStatechartGeneration phaseStatechartGenerationTask : javaUtil.filter(genmodel.getTasks(), PhaseStatechartGeneration.class)) {
			Package parentPackage = StatechartModelDerivedFeatures.getContainingPackage(phaseStatechartGenerationTask.getStatechart());
			packageImports.remove(parentPackage);
		}
		for (Package packageImport : packageImports) {
			int index = genmodel.getPackageImports().indexOf(packageImport);
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.WARNING, 
					"This Gamma package import is not used.",
					new ReferenceInfo(GenmodelModelPackage.Literals.GEN_MODEL__PACKAGE_IMPORTS, index)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkYakinduImports(GenModel genmodel) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		Set<Statechart> statechartImports = genmodel.getStatechartImports().stream().collect(Collectors.toSet());
		for (YakinduCompilation statechartCompilationTask : javaUtil.filter(genmodel.getTasks(), YakinduCompilation.class)) {
			statechartImports.remove(statechartCompilationTask.getStatechart()); //remove removeAll
		}
		for (Statechart statechartImport : statechartImports) {
			int index = genmodel.getStatechartImports().indexOf(statechartImport);
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.WARNING, 
					"This Yakindu import is not used.",
					new ReferenceInfo(GenmodelModelPackage.Literals.GEN_MODEL__STATECHART_IMPORTS, index)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTraceImports(GenModel genmodel) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		Set<ExecutionTrace> traceImports = genmodel.getTraceImports().stream().collect(Collectors.toSet());
		for (TestGeneration testGenerationTask : javaUtil.filter(genmodel.getTasks(), TestGeneration.class)) {
			traceImports.remove(testGenerationTask.getExecutionTrace());
		}
		for (TestReplayModelGeneration testReplayModelGeneration : javaUtil.filter(genmodel.getTasks(), TestReplayModelGeneration.class)) {
			traceImports.remove(testReplayModelGeneration.getExecutionTrace());
		}
		for (ExecutionTrace traceImport : traceImports) {
			int index = genmodel.getTraceImports().indexOf(traceImport);
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.WARNING, 
					"This execution trace import is not used.",
					new ReferenceInfo(GenmodelModelPackage.Literals.GEN_MODEL__TRACE_IMPORTS, index)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkParameters(ComponentReference componentReference) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		Component type = componentReference.getComponent();
		if (componentReference.getArguments().size() != type.getParameterDeclarations().size()) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"The number of arguments is wrong.",
					new ReferenceInfo(ExpressionModelPackage.Literals.ARGUMENTED_ELEMENT__ARGUMENTS, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkComponentInstanceArguments(AnalysisModelTransformation analysisModelTransformation) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		try {
			ModelReference modelReference = analysisModelTransformation.getModel();
			if (modelReference instanceof ComponentReference) {
				ComponentReference componentReference = (ComponentReference)modelReference;
				Component type = componentReference.getComponent();
				List<ParameterDeclaration> parameters = type.getParameterDeclarations();
				for (var i = 0; i < parameters.size(); i++) {
					ParameterDeclaration parameter = parameters.get(i);
					Expression argument = modelReference.getArguments().get(i);
					Type declarationType = parameter.getType();
					ExpressionType argumentType = typeDeterminator.getType(argument);
					if (!typeDeterminator.equals(declarationType, argumentType)) {
						validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
								"The types of the declaration and the right hand side expression are not the same: " +
								typeDeterminator.transform(declarationType).toString().toLowerCase() + " and " +
								argumentType.toString().toLowerCase() + ".", new ReferenceInfo(ExpressionModelPackage.Literals.ARGUMENTED_ELEMENT__ARGUMENTS, i)));
					} 
				}
			}
		} catch (Exception exception) {
			// There is a type error on a lower level, no need to display the error message on this level too
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkIfAllInterfacesMapped(StatechartCompilation statechartCompilation) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		Set<InterfaceScope> interfaces = new HashSet<InterfaceScope>();//(Set<InterfaceScope>)statechartCompilation.getStatechart().getScopes().stream().filter(it -> it instanceof InterfaceScope).collect(Collectors.toSet());
		EList<Scope> scopes = statechartCompilation.getStatechart().getScopes();
		interfaces = javaUtil.filter(scopes, InterfaceScope.class).stream().collect(Collectors.toSet());

		Set<InterfaceScope> mappedInterfaces = new HashSet<InterfaceScope>();//statechartCompilation.getInterfaceMappings().stream().map(it -> it.get);///.map(it -> it.getYakinduInterface()).collect(Collectors.toSet());
		for (InterfaceMapping interfaceMapping: statechartCompilation.getInterfaceMappings()) {
			mappedInterfaces.add(interfaceMapping.getYakinduInterface());
		}
		interfaces.removeAll(mappedInterfaces);
		if (!interfaces.isEmpty()) {
			Set<InterfaceScope> interfacesWithEvents = interfaces.stream().filter(it -> !it.getEvents().isEmpty()).collect(Collectors.toSet());
			Set<InterfaceScope> interfacesWithoutEvents = interfaces.stream().filter(it -> it.getEvents().isEmpty()).collect(Collectors.toSet());
			if (!interfacesWithEvents.isEmpty()) {
				for (InterfaceScope interfacesWithEventsMap : interfacesWithEvents) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"The following interfaces with events are not mapped: " + interfacesWithEventsMap.getName() + ".",
							new ReferenceInfo(GenmodelModelPackage.Literals.YAKINDU_COMPILATION__STATECHART, null)));
				}
			}
			if (!interfacesWithoutEvents.isEmpty()) {
				for (InterfaceScope interfacesWithoutEventsMap : interfacesWithoutEvents) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.INFO, 
							"The following interfaces without events are not mapped: " + interfacesWithoutEventsMap.getName() + ".",
							new ReferenceInfo(GenmodelModelPackage.Literals.YAKINDU_COMPILATION__STATECHART, null)));
				}
			}
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkInterfaceConformance(InterfaceMapping mapping) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		if (!(checkConformance(mapping))) {
			switch (mapping.getRealizationMode()) {
				case PROVIDED:
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"In case of provided realization mode number of in/out events must equal to the number of in/out events in the Gamma interface and vice versa.",
							new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__YAKINDU_INTERFACE, null)));
				case REQUIRED:
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"In case of required realization mode number of in/out events must equal to the number of out/in events in the Gamma interface and vice versa",
							new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__YAKINDU_INTERFACE, null)));
				default:
					throw new IllegalArgumentException("Such interface realization mode is not supported: " + mapping.getRealizationMode());
			}
		}
		return validationResultMessages;
	}
	
	/** It checks the events of the parent interfaces as well. */
	public boolean checkConformance(InterfaceMapping mapping) {
		long yOut = mapping.getYakinduInterface().getEvents().stream()
				.filter(it -> it.getDirection() == Direction.OUT).count();
		long yIn = mapping.getYakinduInterface().getEvents().stream()
				.filter(it -> it.getDirection() == Direction.IN).count();
		long gOut = StatechartModelDerivedFeatures.getAllEventDeclarations(mapping.getGammaInterface())
				.stream().filter(it -> it.getDirection() != EventDirection.IN).count(); // Regarding in-out events
		long gIn = StatechartModelDerivedFeatures.getAllEventDeclarations(mapping.getGammaInterface())
				.stream().filter(it -> it.getDirection() != EventDirection.OUT).count(); // Regarding in-out events
		RealizationMode realMode = mapping.getRealizationMode();
		return (realMode == RealizationMode.PROVIDED && yOut == gOut && yIn == gIn) ||
			(realMode == RealizationMode.REQUIRED && yOut == gIn && yIn == gOut);
	}
	
	public Collection<ValidationResultMessage> checkInterfaceMappingWithoutEventMapping(InterfaceMapping mapping) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		// 0 event mapping is acceptable if the two interfaces are equal
		RealizationMode realizationMode = mapping.getRealizationMode();
		if (mapping.getEventMappings().size() == 0) {
			// If the interface has in-out events, 0 event mapping is surely not acceptable
			if (!(mapping.getGammaInterface().getEvents().stream().filter(it -> it.getDirection() == EventDirection.INOUT).count() == 0)) { //TODO megk�rdezni Benc�t, hogy ez j�-e �gy empty helyett
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						"The Gamma interface has in-out events, thus an automatic mapping is not possible",
						new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__YAKINDU_INTERFACE, null)));
				return validationResultMessages;
			}
			for (Event yakinduEvent : mapping.getYakinduInterface().getEvents()) {
				List<hu.bme.mit.gamma.statechart.interface_.Event> gammaEvents = mapping.getGammaInterface().getEvents()
						.stream().map(it -> it.getEvent())
						.filter(it -> it.getName().equals(yakinduEvent.getName()))
						.collect(Collectors.toList());
				hu.bme.mit.gamma.statechart.interface_.Event gammaEvent = gammaEvents.get(0);
				if (!(gammaEvents.size() == 1 && checkParameters(yakinduEvent, gammaEvent)
					&& areWellDirected(realizationMode, yakinduEvent, (EventDeclaration)gammaEvent.eContainer()))) {
					String typeName = "";
					if (yakinduEvent.getType() != null) {
						typeName = " : " + yakinduEvent.getType().getName();
						} else {
						typeName = "";
						}
						
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"Interface mapping without event mapping is only possible if the names and types of the events of the interfaces are equal. " 
							+ yakinduEvent.getName() + typeName + " has no equivalent event in the Gamma interface.",
							new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__YAKINDU_INTERFACE, null)));
					}
					
				}			
			}
	
		return validationResultMessages;
	}
	
	/**
	 * Checks whether the event directions conform to the realization mode.
	 */
	public boolean areWellDirected(RealizationMode interfaceType, org.yakindu.base.types.Event yEvent, EventDeclaration gEvent) {
		if (interfaceType == RealizationMode.PROVIDED) {
			return (yEvent.getDirection() == Direction.OUT && gEvent.getDirection() != EventDirection.IN) ||
			(yEvent.getDirection() == Direction.IN && gEvent.getDirection() != EventDirection.OUT);
		}
		else if (interfaceType == RealizationMode.REQUIRED) {
			return (yEvent.getDirection() == Direction.OUT && gEvent.getDirection() != EventDirection.OUT) ||
			(yEvent.getDirection() == Direction.IN && gEvent.getDirection() != EventDirection.IN);
		}
		else {
			throw new IllegalArgumentException("No such direction: " + interfaceType);
		}
	}
	
	public Collection<ValidationResultMessage> checkMappingCount(InterfaceMapping mapping) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		// Check only if the interface mapping is not trivial (size != 0)
		if (mapping.getEventMappings().size() != 0 && mapping.getYakinduInterface().getEvents().size() != mapping.getEventMappings().size()) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
					"Each Yakindu event has to be mapped exactly once.",
					new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__YAKINDU_INTERFACE, null)));
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkYakinduInterfaceUniqueness(InterfaceMapping mapping) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		Set<InterfaceScope> interfaces = new HashSet<InterfaceScope>();
		StatechartCompilation statechartCompilation = (StatechartCompilation)mapping.eContainer();
		for (InterfaceScope interface_ : statechartCompilation.getInterfaceMappings().stream().map(it -> it.getYakinduInterface()).collect(Collectors.toList())) {
			if (interfaces.contains(interface_)){
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						"Each Yakindu event has to be mapped exactly once.",
						new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__YAKINDU_INTERFACE, null)));
			}
			else {
				interfaces.add(interface_);
			}			
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkEventMappingCount(InterfaceMapping mapping) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		Set<Event> mappedYakinduEvents = new HashSet<Event>();
		Map<hu.bme.mit.gamma.statechart.interface_.Event, Set<Event>> mappedGammaEvents = new HashMap<hu.bme.mit.gamma.statechart.interface_.Event, Set<Event>>();
		for (EventMapping eventMapping : mapping.getEventMappings()) {
			org.yakindu.base.types.Event yakinduEvent = eventMapping.getYakinduEvent();
			hu.bme.mit.gamma.statechart.interface_.Event gammaEvent = eventMapping.getGammaEvent();
			// Yakindu validation
			if (mappedYakinduEvents.contains(yakinduEvent)) {
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						"This event is mapped multiple times: " + yakinduEvent.getName() + ".",
						new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__EVENT_MAPPINGS, null)));
			}
			else {
				mappedYakinduEvents.add(yakinduEvent);			
			}
			// Gamma validation
			if (mappedGammaEvents.containsKey(gammaEvent)) {
				EventDeclaration gammaEventDeclaration = (EventDeclaration)gammaEvent.eContainer();
				if (gammaEventDeclaration.getDirection() == EventDirection.INOUT) {
					Set<Event> yakinduEventSet = mappedGammaEvents.get(gammaEvent);
					yakinduEventSet.add(yakinduEvent);
					// A single in and a single out event has to be now in yakinduEventSet
					if (!(yakinduEventSet.stream().filter(it -> it.getDirection() == Direction.IN).count() == 1 &&
							yakinduEventSet.stream().filter(it -> it.getDirection() == Direction.OUT).count() == 1)) {
						validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
								"A single in and a single out event has to be mapped onto this Gamma event: " + gammaEvent.getName() + ".",
								new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__EVENT_MAPPINGS, null)));
					}
				}
				else {
					// Not an in-out event
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"Multiple Yakindu events are mapped to this Gamma event: " + gammaEvent.getName() + ".",
							new ReferenceInfo(GenmodelModelPackage.Literals.INTERFACE_MAPPING__EVENT_MAPPINGS, null)));
				}
			}
			else {
				// First entry
				mappedGammaEvents.put(gammaEvent, CollectionLiterals.newHashSet(yakinduEvent));			
			}
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkEventConformance(EventMapping mapping) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		InterfaceMapping ifReal = (InterfaceMapping)mapping.eContainer();
		if (!(checkConformance(mapping))) {
			switch (ifReal.getRealizationMode()) {
				case PROVIDED:
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"In case of provided realization mode Yakindu events must have the same direction and parameter as Gamma events.",
							new ReferenceInfo(GenmodelModelPackage.Literals.EVENT_MAPPING__YAKINDU_EVENT, null)));
				case REQUIRED:	
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"In case of required realization mode Yakindu events must have the opposite direction and same parameter of Gamma events.",
							new ReferenceInfo(GenmodelModelPackage.Literals.EVENT_MAPPING__YAKINDU_EVENT, null)));
				default:
				throw new IllegalArgumentException("Such interface realization mode is not supported: " + ifReal.getRealizationMode());				
			}
		}
		return validationResultMessages;
	}
	
	public Collection<ValidationResultMessage> checkTraces(TestGeneration testGeneration) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		GenModel genmodel = (GenModel)testGeneration.eContainer(); 
		Set<String> usedInterfaces = testGeneration.getExecutionTrace().getComponent().getPorts().stream()
				.map(it -> it.getInterfaceRealization().getInterface().getName())
				.collect(Collectors.toSet()); 
		List<List<Scope>> interfaceCompilation = javaUtil.filter(genmodel.getTasks(), InterfaceCompilation.class).stream()
				.map(it -> it.getStatechart().getScopes())
				.collect(Collectors.toList());
		Iterable<Scope> flattenList = javaUtil.flatten(interfaceCompilation);
		Set<String> transformedInterfaces = javaUtil.filter(flattenList, InterfaceScope.class).stream()
				.map(it -> it.getName())
				.collect(Collectors.toSet());

		usedInterfaces.retainAll(transformedInterfaces);
		if (!usedInterfaces.isEmpty()) {
			validationResultMessages.add(new ValidationResultMessage(ValidationResult.WARNING, 
					"This trace depends on interfaces " + usedInterfaces + ", which seem to be about to be recompiled. " + 
							"The recompilation of interfaces just before the generation of tests might cause a break in the generated test suite.",
					new ReferenceInfo(GenmodelModelPackage.Literals.TEST_GENERATION__EXECUTION_TRACE, null)));
		}
		return validationResultMessages;
	}
	
	public boolean checkConformance(EventMapping mapping) {
		org.yakindu.base.types.Event yEvent = mapping.getYakinduEvent();
		EventDeclaration gEvent = (EventDeclaration)mapping.getGammaEvent().eContainer();
		InterfaceMapping ifReal = (InterfaceMapping)mapping.eContainer();
		RealizationMode realMode = ifReal.getRealizationMode();
		return checkEventConformance(yEvent, gEvent, realMode);
	}
	
	public boolean checkEventConformance(org.yakindu.base.types.Event yEvent, EventDeclaration gEvent, RealizationMode realMode) {
		switch (realMode) {
			 // Regarding in-out events
			case PROVIDED:
				return yEvent.getDirection() == Direction.IN && gEvent.getDirection() != EventDirection.OUT && checkParameters(yEvent, gEvent.getEvent()) ||
					yEvent.getDirection() == Direction.OUT && gEvent.getDirection() != EventDirection.IN && checkParameters(yEvent, gEvent.getEvent());
			case REQUIRED:
				return yEvent.getDirection() == Direction.IN && gEvent.getDirection() != EventDirection.IN && checkParameters(yEvent, gEvent.getEvent()) ||
					yEvent.getDirection() == Direction.OUT && gEvent.getDirection() != EventDirection.OUT && checkParameters(yEvent, gEvent.getEvent());
			default:
				throw new IllegalArgumentException("Such interface realization mode is not supported: " + realMode);				
		}
	}
	
	public boolean checkParameters(Event yakinduEvent, hu.bme.mit.gamma.statechart.interface_.Event gEvent) {
		// event.type is null not void if no explicit type is declared
		if (yakinduEvent.getType() == null && gEvent.getParameterDeclarations().isEmpty()) {
			return true;
		}
		if (!gEvent.getParameterDeclarations().isEmpty()) {
			Type eventType = gEvent.getParameterDeclarations().get(0).getType();
			if (eventType instanceof IntegerTypeDefinition) {
				if (yakinduEvent.getType() == null) {
					return false;
				}
				return yakinduEvent.getType().getName().equals("integer") ||
						yakinduEvent.getType().getName().equals("string"); 
			}
			else if (eventType instanceof BooleanTypeDefinition) {
				if (yakinduEvent.getType() == null) {
					return false;
				}
				return yakinduEvent.getType().getName().equals("boolean");
			}
			else if (eventType instanceof DecimalTypeDefinition) {
				if(yakinduEvent.getType() == null) {
					return false;
				}
				return yakinduEvent.getType().getName().equals("real");
			}
			else {
				throw new IllegalArgumentException("Not known type: " + gEvent.getParameterDeclarations().get(0).getType());
			}
					
		}
		return false;
	}
	
	public Collection<ValidationResultMessage> checkComponentInstanceReferences(ComponentInstanceReference reference) {
		Collection<ValidationResultMessage> validationResultMessages = new ArrayList<ValidationResultMessage>();
		List<ComponentInstance> instances = reference.getComponentInstanceHierarchy();
		if (instances.isEmpty()) {
			return validationResultMessages;
		}
		for (var i = 0; i < instances.size() - 1; i++) {
			ComponentInstance instance = instances.get(i);
			ComponentInstance nextInstance = instances.get(i + 1);
			Component type = StatechartModelDerivedFeatures.getDerivedType(instance);
			List<EObject> containedInstances = type.eContents();
			if (!containedInstances.contains(nextInstance)) {
				validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
						instance.getName() + " does not contain component instance " + nextInstance.getName(),
						new ReferenceInfo(CompositeModelPackage.Literals.COMPONENT_INSTANCE_REFERENCE__COMPONENT_INSTANCE_HIERARCHY, i)));
			}
		}
		AnalysisModelTransformation model = ecoreUtil.getContainerOfType(reference, AnalysisModelTransformation.class);
		if (model != null) {
			ModelReference modelReference = model.getModel();
			if (modelReference instanceof ComponentReference) {
				ComponentReference componentReference = (ComponentReference)modelReference;
				Component component = componentReference.getComponent();
				List<ComponentInstance> containedComponents = javaUtil.filter(component.eContents(), ComponentInstance.class);
				ComponentInstance firstInstance = instances.get(0);
				if (!containedComponents.contains(firstInstance)) {
					validationResultMessages.add(new ValidationResultMessage(ValidationResult.ERROR, 
							"The first component instance must be the component of " + component.getName(),
							new ReferenceInfo(CompositeModelPackage.Literals.COMPONENT_INSTANCE_REFERENCE__COMPONENT_INSTANCE_HIERARCHY, 0)));
				}
			}
		}
		return validationResultMessages;
	}
	
}
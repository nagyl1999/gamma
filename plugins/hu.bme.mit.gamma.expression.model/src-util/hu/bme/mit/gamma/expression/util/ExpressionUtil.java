package hu.bme.mit.gamma.expression.util;

import java.math.BigInteger;
import java.util.Collection;
import java.util.HashSet;
import java.util.Set;

import org.eclipse.emf.ecore.EObject;

import hu.bme.mit.gamma.expression.model.Expression;
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory;
import hu.bme.mit.gamma.expression.model.IntegerLiteralExpression;

public class ExpressionUtil {

	protected ExpressionEvaluator evaluator = new ExpressionEvaluator();
	
	protected ExpressionModelFactory factory = ExpressionModelFactory.eINSTANCE;
	
	@SuppressWarnings("unchecked")
	public  <T extends EObject> T getContainer(EObject element, Class<T> _class) {
		EObject container = element.eContainer();
		if (container == null) {
			return null;
		}
		if (_class.isInstance(container)) {
			return (T) container;
		}
		return getContainer(container, _class);
	}
	
	public Set<Expression> removeDuplicatedExpressions(Collection<Expression> expressions) {
		Set<Integer> integerValues = new HashSet<Integer>();
		Set<Boolean> booleanValues = new HashSet<Boolean>();
		Set<Expression> evaluatedExpressions = new HashSet<Expression>();
		for (Expression expression : expressions) {
			try {
				// Integers and enums
				int value = evaluator.evaluateInteger(expression);
				if (!integerValues.contains(value)) {
					integerValues.add(value);
					IntegerLiteralExpression integerLiteralExpression = factory.createIntegerLiteralExpression();
					integerLiteralExpression.setValue(BigInteger.valueOf(value));
					evaluatedExpressions.add(integerLiteralExpression); 
				}
			} catch (Exception e) {}
			// Excluding branches
			try {
				// Boolean
				boolean bool = evaluator.evaluateBoolean(expression);
				if (!booleanValues.contains(bool)) {
					booleanValues.add(bool);
					evaluatedExpressions.add(bool ? factory.createTrueExpression() : factory.createFalseExpression());
				}
			} catch (Exception e) {}
		}
		return evaluatedExpressions;
	}
	
}
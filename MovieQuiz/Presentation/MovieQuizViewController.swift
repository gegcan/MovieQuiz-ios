import UIKit

final class MovieQuizViewController: UIViewController, QuestionFactoryDelegate {
    
    private var currentQuestionIndex = 0 // счетчик, номер вопроса
    private var correctAnswers = 0 // счётчик правильных ответов
    
    private let questionsAmount: Int = 10
    private var currentQuestion: QuizeQuestion?
    private var questionFactory: QuestionFactoryProtocol?
    private var alertPresenterProtocol: AlertPresenterProtocol?
    private var statisticsService: StatisticService?
    
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var textLabel: UILabel!
    @IBOutlet private var counterLabel: UILabel!
    @IBOutlet weak var noButton: UIButton!
    @IBOutlet weak var yesButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        questionFactory = QuestionFactory(delegate: self)
        alertPresenterProtocol = AlertPresenter(viewController: self)
        statisticsService = StatisticServiceImplementation()
        
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        
        questionFactory?.requestNextQuestion()
    }
    
    // MARK: - QuestionFactoryDelegate
    
    func didReceiveNextQuestion(question: QuizeQuestion?) {
        guard let question = question else {
            return
        }
        
        currentQuestion = question
        let viewModel = convert(model: question)
        DispatchQueue.main.async { [weak self] in
            self?.show(quize: viewModel)
        }
    }
    
    private func convert(model: QuizeQuestion) -> QuizeStepViewModel {
        let questionStep = QuizeStepViewModel(
            image: UIImage(named: model.image) ?? UIImage(),
            question: model.text,
            questionNumber: "\(currentQuestionIndex + 1)/\(questionsAmount)")
        return questionStep
    }
    
    private func show(quize step: QuizeStepViewModel) {
        imageView.image = step.image
        textLabel.text = step.question
        counterLabel.text = step.questionNumber
    }
    
    private func showNextQuestionOrResults() {
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 0
        imageView.layer.borderColor = nil
        
        noButton.isEnabled = true
        yesButton.isEnabled = true
        
        if currentQuestionIndex == questionsAmount - 1 {
            finalResult()
        } else {
            currentQuestionIndex += 1
            self.questionFactory?.requestNextQuestion()
        }
    }
    
    private func finalResult() {
        statisticsService?.store(correct: correctAnswers, total: questionsAmount)
        
        let alertModel = AlertModel(
            title: "Игра окончена",
            message: makeResultMessage(),
            buttonText: "Сыграть еще раз",
            completion: {[weak self] in
                self?.currentQuestionIndex = 0
                self?.correctAnswers = 0
                self?.questionFactory?.requestNextQuestion()
            }
        )
        alertPresenterProtocol?.showAlert(alertModel: alertModel)
    }
    
    private func makeResultMessage() -> String {
        
        guard let statisticsService = statisticsService, let bestGame = statisticsService.bestGame else {
            return ""
        }
        let text = "Ваш результат: \(correctAnswers)/\(questionsAmount)"
        let playedQuizCauntity = "Количество сыгранных квизов: \(statisticsService.gamesCount)"
        let accuracy = "Средняя точность: \(String(format: "%.2f", statisticsService.totalAccuracy))%"
        let bestResult = "Рекорд: \(bestGame.correct)/\(questionsAmount) (\(bestGame.date.dateTimeString))"
        let result = [ text, playedQuizCauntity, bestResult, accuracy].joined(separator: "\n")
        return result
    }
    
    private func showAnswerResult(isCorrect: Bool) {
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 8
        imageView.layer.borderColor = isCorrect ? UIColor.ypGreen.cgColor : UIColor.ypRed.cgColor
        
        if isCorrect {
            correctAnswers += 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.showNextQuestionOrResults()
        }
    }
    
    // метод, который предотвращает повторное нажатие на кнопки
    private func isEnabledButtons() {
        noButton.isEnabled = false
        yesButton.isEnabled = false
    }
    
    @IBAction private func yesButtonClicked(_ sender: UIButton) {
        guard let currentQuestion = currentQuestion else {
            return
        }
        let givenAnswer = true
        isEnabledButtons()
        
        showAnswerResult(isCorrect: givenAnswer == currentQuestion.correctAnswer)
    }
    
    @IBAction private func noButtonClicked(_ sender: UIButton) {
        guard let currentQuestion = currentQuestion else {
            return
        }
        let givenAnswer = false
        isEnabledButtons()
        
        showAnswerResult(isCorrect: givenAnswer == currentQuestion.correctAnswer)
    }
}

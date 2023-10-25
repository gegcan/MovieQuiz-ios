import UIKit

final class MovieQuizViewController: UIViewController, QuestionFactoryDelegate {
    
    private var correctAnswers = 0 // счётчик правильных ответов
    
    private var currentQuestion: QuizQuestion?
    private var questionFactory: QuestionFactoryProtocol?
    private var alertPresenterProtocol: AlertPresenterProtocol?
    private var statisticsService: StatisticService?
    private let presenter = MovieQuizPresenter()
    
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var textLabel: UILabel!
    @IBOutlet private var counterLabel: UILabel!
    @IBOutlet weak var noButton: UIButton!
    @IBOutlet weak var yesButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        questionFactory = QuestionFactory(moviesLoader: MoviesLoader(), delegate: self)
        alertPresenterProtocol = AlertPresenter(viewController: self)
        statisticsService = StatisticServiceImplementation()
        presenter.viewController = self
        
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        activityIndicator.hidesWhenStopped = true
        
        showLoadingIndicator()
        questionFactory?.requestNextQuestion()
        questionFactory?.loadData()
    }
    
    // MARK: - QuestionFactoryDelegate
    
    func didReceiveNextQuestion(question: QuizQuestion?) {
        guard let question = question else {
            return
        }
        
        currentQuestion = question
        let viewModel = presenter.convert(model: question)
        DispatchQueue.main.async { [weak self] in
            self?.show(quiz: viewModel)
        }
    }
    
    private func show(quiz step: QuizStepViewModel) {
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
        
        if presenter.isLastQuestion() {
            finalResult()
        } else {
            presenter.switchToNextQuestion()
            self.questionFactory?.requestNextQuestion()
        }
        hideLoadingIndicator()
    }
    
    private func finalResult() {
        statisticsService?.store(correct: correctAnswers, total: presenter.questionsAmount)
        
        let alertModel = AlertModel(
            title: "Игра окончена",
            message: makeResultMessage(),
            buttonText: "Сыграть ещё раз",
            completion: {[weak self] in
                self?.presenter.resetQuestionIndex()
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
        let text = "Ваш результат: \(correctAnswers)/\(presenter.questionsAmount)"
        let playedQuizCauntity = "Количество сыгранных квизов: \(statisticsService.gamesCount)"
        let accuracy = "Средняя точность: \(String(format: "%.2f", statisticsService.totalAccuracy))%"
        let bestResult = "Рекорд: \(bestGame.correct)/\(presenter.questionsAmount) (\(bestGame.date.dateTimeString))"
        let result = [ text, playedQuizCauntity, bestResult, accuracy].joined(separator: "\n")
        return result
    }
    
    func showAnswerResult(isCorrect: Bool) {
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 8
        imageView.layer.borderColor = isCorrect ? UIColor.ypGreen.cgColor : UIColor.ypRed.cgColor
        
        if isCorrect {
            correctAnswers += 1
        }
        
        showLoadingIndicator()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.showNextQuestionOrResults()
        }
    }
    
    // запускаю активити индикатор
    private func showLoadingIndicator() {
        activityIndicator.startAnimating() // включаем анимацию
    }
    
    private func hideLoadingIndicator() {
        activityIndicator.stopAnimating() // выключаем анимацию
    }
    
    private func showNetworkError(message: String) {
        hideLoadingIndicator()
        
        let model = AlertModel(title: "Ошибка",
                               message: message,
                               buttonText: "Попробовать еще раз") { [weak self] in
            guard let self = self else { return }
            
            self.presenter.resetQuestionIndex()
            self.correctAnswers = 0
            
            self.questionFactory?.requestNextQuestion()
        }
        
        alertPresenterProtocol?.showAlert(alertModel: model)
    }
    
    // метод, который предотвращает повторное нажатие на кнопки
    private func isEnabledButtons() {
        noButton.isEnabled = false
        yesButton.isEnabled = false
    }
    
    func didLoadDataFromServer() {
        activityIndicator.isHidden = true // скрываем индикатор загрузки
        questionFactory?.requestNextQuestion()
    }
    
    func didFailToLoadData(with error: Error) {
        showNetworkError(message: error.localizedDescription) // возьмём в качестве сообщения описание ошибки
    }
    
    @IBAction private func yesButtonClicked(_ sender: UIButton) {
        presenter.currentQuestion = currentQuestion
        presenter.yesButtonClicked()
        isEnabledButtons()
    }
    
    @IBAction private func noButtonClicked(_ sender: UIButton) {
        presenter.currentQuestion = currentQuestion
        presenter.noButtonClicked()
        isEnabledButtons()
    }
}

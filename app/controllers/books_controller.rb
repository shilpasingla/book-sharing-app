class BooksController < ApplicationController

  def index
    @books = Book.all
  end

  def own_books
    user = User.where(name: session[:cas_user]).first
    if user
      @books = user.books.uniq
      render template: 'books/own_books'
    end
  end

  def shared_books
    owner_id = User.where(name: session[:cas_user]).pluck(:id).first
    borrowed_book_ids = BookBorrower.where(owner_id: owner_id).pluck(:book_id)
    @books = Book.where(id: borrowed_book_ids)
    render template: 'books/shared_books'
  end

  def borrowed_books
    borrower_id = User.where(name: session[:cas_user]).pluck(:id).first
    borrowed_book_ids = BookBorrower.where(borrower_id: borrower_id).pluck(:book_id)
    @books = Book.where(id: borrowed_book_ids)
    render template: 'books/borrowed_books'
  end

  def get_by_isbn
    isbn = params[:isbn]
    response_book = GoogleBooks.search(isbn).first;
    if response_book.isbn_10 == isbn
      possible_book = Book.new(title: response_book.title, description: response_book.description,
                               author: response_book.authors)
    end
    render json: {possible_book: possible_book, image_link: response_book.image_link}, status: :ok
  end

  def get_by_title
    title = params[:title]
    response_book = GoogleBooks.search(title).first;
    possible_book = Book.new(title: response_book.title, description: response_book.description,
                             author: response_book.authors, isbn: response_book.isbn_10)
    render json: {possible_book: possible_book, image_link: response_book.image_link}, status: :ok
  end

  def new
    @book = Book.new
    respond_to do |format|
      format.html { render partial: 'form' }
    end
  end

  def create
    image_url = params[:image_url] + '&printsec=' + params[:printsec] + '&img=' + params[:img] + '&zoom=' + params[:zoom] + '&source=' + params[:source]
    book = Book.new(title: params['book']['title'], author: params['book']['author'], isbn: params['book']['isbn'],
                    edition: params['book']['edition'], description: params['book']['description'], image_url: image_url)

    if book.save_or_update_with_user_and_tags(session[:cas_user], params[:tags])
      respond_to do |format|
        format.json { render json: book, status: :created }
      end

    else
      if params[:tags].blank?
        book.errors['tags'] = "can't be blank"
      end
      respond_to do |format|
        format.json { render json: book.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
    @book = Book.find(params[:id])
    owner_id = User.where(name: session[:cas_user]).pluck(:id).first
    @book_borrowers = BookBorrower.where(book_id: @book.id, owner_id: owner_id).includes(:borrower)
    bookOwners = @book.owners
    @copies = bookOwners.group(:name).count
    @isOnwerViewingBook = bookOwners.pluck(:name).include?(session[:cas_user])
  end

  def edit
    @book = Book.find(params[:id])
  end

  def update
    @book = Book.find(params[:id])

    if @book.update(params[:book].permit(:title, :description, :isbn, :edition))
      redirect_to @book
    else
      render 'edit'
    end
  end

  def destroy
    book = Book.find(params[:id])
    user = User.where(name: session[:cas_user]).first
    book.owners.delete(user)

    #book_borrower = BookBorrower.where('book_id = :bookId AND owner_id = :ownerId', {bookId: book.id, ownerId: user.id})
    #
    #if book_borrower
    #  book_borrower.each { |borrower|
    #    borrower.destroy
    #  }
    #end
    redirect_to books_own_books_path
  end

end

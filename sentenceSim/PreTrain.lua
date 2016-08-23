--
-- Created by IntelliJ IDEA.
-- User: zhuangli
-- Date: 12/08/2016
-- Time: 11:17 PM
-- To change this template use File | Settings | File Templates.
--


--
-- Created by IntelliJ IDEA.
-- User: zhuangli
-- Date: 4/08/2016
-- Time: 3:39 AM
-- To change this template use File | Settings | File Templates.
--

require('..')

cmd = torch.CmdLine()
cmd:text()
cmd:text('Train sentence similarity model')
cmd:text()
cmd:text('Options')
cmd:option('-data_dir','data','data directory. Should contain the training data and embedding')
cmd:option('-hidden_size', 200, 'size of LSTM internal state')
cmd:option('-model', 'lstm', 'lstm,gru or rnn')
cmd:option('-learning_rate',0.05,'learning rate')
cmd:option('-reg',0.0001,'regularization rate')
cmd:option('-max_epochs',10,'max training epoch')
cmd:option('-seq_length',10,'number of timesteps to unroll for')
cmd:option('-batch_size',100,'number of sequences to train on in parallel')
cmd:option('-gpuidx',0,'which gpu to use. 0 = use CPU')
cmd:option('-model_path','/model_name','pre-train model name')
cmd:text()

-- parse input params
opt = cmd:parse(arg)

local embedding_path = opt.data_dir..'/embedding/glove.6B.300d.th'
local vocab_path = opt.data_dir..'/embedding/glove.6B.vocab'
local train_path = opt.data_dir..'/train/pit_train.txt'
local model_path = opt.data_dir..'/model_ser'..opt.model_path
local batch_size = opt.batch_size
local seq_length = opt.seq_length
local epochs = opt.max_epochs

local vocab,emb_vecs = sentenceSim.read_embedding(vocab_path, embedding_path)
local emb_dim = emb_vecs:size(2)
local ori_vocab = sentenceSim.Vocab(vocab_path)

vocab:add_unk_token()
vocab:add_pad_token()
vocab:add_end_token()
vocab:add_start_token()
local num_unk = 0
local vecs = torch.Tensor(vocab.size, emb_dim)
for i = 1, vocab.size do
    local w = vocab:token(i)
    if ori_vocab:contains(w) then
        vecs[i] = emb_vecs[ori_vocab:index(w)]
    else
        num_unk = num_unk + 1
        if i == vocab.pad_index then
            vecs[i]:zero()
        else
            vecs[i]:uniform(-0.05, 0.05)
        end
    end
end

--print (vecs[71293])
--vecs = torch.zeros(vecs:size())
ori_vocab = nil
print('new token count = ' .. num_unk)

local train_data = sentenceSim.load_pretrain_data(train_path,vocab,batch_size,seq_length)
local train_avg_length = train_data.sum_length/(train_data.size*2)


local unigram = sentenceSim.read_unigram(vocab)
--print ('Sum is '..unigram:sum())
printf('max epochs = %d\n', epochs)
printf('training data size = %d\n', train_data.size)
printf('dumped training data size = %d\n', train_data.dump_data_size)
printf('average training data length = %d\n', train_avg_length)
printf('pre-train model path %s\n',model_path)
printf('unknown words = %d\n', train_data.unk_words)
printf('frequency count = %d\n', unigram:sum())
vocab = nil
emb_vecs = nil
collectgarbage()
--load model

--print (unigram)

-- initialize model
--print (finetune)
local model = sentenceSim.LSTMSim{
    unigram = unigram,
    emb_vecs   = vecs,
    structure  = opt.model,
    mem_dim    = opt.hidden_size,
    gpuidx = opt.gpuidx,
    batch_size = opt.batch_size,
    reg = opt.reg,
    seq_length = opt.seq_length,
    learning_rate = opt.learning_rate,
    finetune = false
}


-- print information
header('model configuration')

model:print_config()

-- train
local train_start = sys.clock()
header('Training model')
for i = 1, epochs do
    local start = sys.clock()
    printf('-- epoch %d\n', i)
    local total_loss = model:pre_train(train_data)
    print('Train loss: '..total_loss)
    printf('-- finished epoch in %.2fs\n', sys.clock() - start)
    if i == opt.max_epochs then
        print('Saving pre-train model')
        model:save(model_path)
    end
end
printf('finished training in %.2fs\n', sys.clock() - train_start)